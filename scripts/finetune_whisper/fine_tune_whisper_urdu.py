import os
import torch
import evaluate
from dataclasses import dataclass
from typing import Any, Dict, List, Union
from datasets import load_dataset, Audio, DatasetDict
from transformers import (
    WhisperFeatureExtractor,
    WhisperTokenizer,
    WhisperProcessor,
    WhisperForConditionalGeneration,
    Seq2SeqTrainingArguments,
    Seq2SeqTrainer,
)

# ── CONFIGURATION ──────────────────────────────────────────────────────────
MODEL_NAME = "openai/whisper-small"
LANGUAGE = "urdu"
LANGUAGE_CODE = "ur"
TASK = "transcribe"
OUTPUT_DIR = "./whisper-small-urdu"

# Hyperparameters
BATCH_SIZE = 8
GRADIENT_ACCUMULATION_STEPS = 2
LEARNING_RATE = 1e-5
MAX_STEPS = 4000
WARMUP_STEPS = 500
EVAL_STEPS = 500
SAVE_STEPS = 500

FREEZE_ENCODER = False  # Set to True to save memory
# ──────────────────────────────────────────────────────────────────────────

def main():
    # 1. Load Dataset
    print("[1/7] Loading Mozilla Common Voice Urdu dataset...")
    # Using 'streaming=False' to download and cache, better for small-medium datasets
    common_voice = DatasetDict()
    common_voice["train"] = load_dataset("mozilla-foundation/common_voice_11_0", LANGUAGE_CODE, split="train+validation", use_auth_token=True)
    common_voice["test"] = load_dataset("mozilla-foundation/common_voice_11_0", LANGUAGE_CODE, split="test", use_auth_token=True)

    # 2. Preprocessing
    print("[2/7] Initializing Feature Extractor, Tokenizer, and Processor...")
    feature_extractor = WhisperFeatureExtractor.from_pretrained(MODEL_NAME)
    tokenizer = WhisperTokenizer.from_pretrained(MODEL_NAME, language=LANGUAGE, task=TASK)
    processor = WhisperProcessor.from_pretrained(MODEL_NAME, language=LANGUAGE, task=TASK)

    # Resample audio to 16kHz (required by Whisper)
    print("Resampling dataset to 16kHz...")
    common_voice = common_voice.cast_column("audio", Audio(sampling_rate=16000))

    def prepare_dataset(batch):
        # Load and resample audio data
        audio = batch["audio"]

        # Compute log-Mel input features from input audio array 
        batch["input_features"] = feature_extractor(audio["array"], sampling_rate=audio["sampling_rate"]).input_features[0]

        # Encode target text to label ids
        batch["labels"] = tokenizer(batch["sentence"]).input_ids
        return batch

    print("Mapping dataset (this may take a while)...")
    common_voice = common_voice.map(prepare_dataset, remove_columns=common_voice.column_names["train"], num_proc=1)

    # 3. Data Collator
    @dataclass
    class DataCollatorSpeechSeq2SeqWithPadding:
        processor: Any

        def __call__(self, features: List[Dict[str, Union[List[int], torch.Tensor]]]) -> Dict[str, torch.Tensor]:
            # split inputs and labels since they have different lengths and need different padding methods
            # first treat the audio inputs by simply returning torch tensors
            input_features = [{"input_features": feature["input_features"]} for feature in features]
            batch = self.processor.feature_extractor.pad(input_features, return_tensors="pt")

            # get the tokenized label sequences
            label_features = [{"input_ids": feature["labels"]} for feature in features]
            # pad the labels to max length
            labels_batch = self.processor.tokenizer.pad(label_features, return_tensors="pt")

            # replace padding with -100 to ignore loss correctly
            labels = labels_batch["input_ids"].masked_fill(labels_batch.attention_mask.ne(1), -100)

            # if bos token is appended in previous tokenization step,
            # cut bos token here as it's append later anyways
            if (labels[:, 0] == self.processor.tokenizer.bos_token_id).all().cpu().item():
                labels = labels[:, 1:]

            batch["labels"] = labels
            return batch

    data_collator = DataCollatorSpeechSeq2SeqWithPadding(processor=processor)

    # 4. Metrics
    print("[3/7] Setting up WER evaluation metric...")
    metric = evaluate.load("wer")

    def compute_metrics(pred):
        pred_ids = pred.predictions
        label_ids = pred.label_ids

        # replace -100 with the pad_token_id
        label_ids[label_ids == -100] = tokenizer.pad_token_id

        # we do not want to group tokens when computing the metrics
        pred_str = tokenizer.batch_decode(pred_ids, skip_special_tokens=True)
        label_str = tokenizer.batch_decode(label_ids, skip_special_tokens=True)

        wer = 100 * metric.compute(predictions=pred_str, references=label_str)

        return {"wer": wer}

    # 5. Load Model
    print("[4/7] Loading Whisper-small model...")
    model = WhisperForConditionalGeneration.from_pretrained(MODEL_NAME)

    # Configure generation
    model.config.forced_decoder_ids = processor.get_decoder_prompt_ids(language=LANGUAGE, task=TASK)
    model.config.suppress_tokens = []
    
    if FREEZE_ENCODER:
        print("Freezing encoder layers to save memory...")
        model.model.encoder.gradient_checkpointing = True
        for param in model.model.encoder.parameters():
            param.requires_grad = False

    # 6. Training Arguments
    print("[5/7] Configuring training arguments...")
    training_args = Seq2SeqTrainingArguments(
        output_dir=OUTPUT_DIR,
        per_device_train_batch_size=BATCH_SIZE,
        gradient_accumulation_steps=GRADIENT_ACCUMULATION_STEPS,
        learning_rate=LEARNING_RATE,
        warmup_steps=WARMUP_STEPS,
        max_steps=MAX_STEPS,
        gradient_checkpointing=True,
        fp16=torch.cuda.is_available(),
        evaluation_strategy="steps",
        per_device_eval_batch_size=8,
        predict_with_generate=True,
        generation_max_length=225,
        save_steps=SAVE_STEPS,
        eval_steps=EVAL_STEPS,
        logging_steps=25,
        report_to=["tensorboard"],
        load_best_model_at_end=True,
        metric_for_best_model="wer",
        greater_is_better=False,
        push_to_hub=False,
    )

    # 7. Start Training
    print("[6/7] Initializing Trainer and starting training...")
    trainer = Seq2SeqTrainer(
        args=training_args,
        model=model,
        train_dataset=common_voice["train"],
        eval_dataset=common_voice["test"],
        data_collator=data_collator,
        compute_metrics=compute_metrics,
        tokenizer=processor.feature_extractor,
    )

    trainer.train()

    # 8. Save Model
    print(f"[7/7] Training complete. Saving model to {OUTPUT_DIR}...")
    trainer.save_model(OUTPUT_DIR)
    processor.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)
    print("Done!")

if __name__ == "__main__":
    main()
