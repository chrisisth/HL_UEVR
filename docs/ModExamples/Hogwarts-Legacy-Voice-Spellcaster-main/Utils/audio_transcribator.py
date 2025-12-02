import os
import json
from vosk import Model, KaldiRecognizer
from pydub import AudioSegment
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

MODEL_PATH = 'model/vosk-model-small-ru-0.22/'
INPUT_DIR = 'All Generated Audios'
OUTPUT_DIR = 'Transcripted_Audios'

model = Model(MODEL_PATH)

def transcribe_audio(audio_path: str) -> str:
    try:
        audio = AudioSegment.from_file(audio_path)
        audio = audio.set_channels(1)
        audio = audio.set_frame_rate(16000)  # Приведение к стандартной частоте

        recognizer = KaldiRecognizer(model, 16000)
        recognizer.SetWords(True)

        audio_bytes = audio.raw_data
        result_text = ""

        for i in range(0, len(audio_bytes), 4000):
            chunk = audio_bytes[i:i + 4000]
            if recognizer.AcceptWaveform(chunk):
                result = json.loads(recognizer.Result())
                result_text += result.get("text", "") + " "

        final_result = json.loads(recognizer.FinalResult())
        result_text += final_result.get("text", "")

        return result_text.strip()

    except Exception as e:
        return f"[ERROR] {audio_path}: {e}"

def process_spell_folder(spell_folder: str):
    spell_path = os.path.join(INPUT_DIR, spell_folder)
    spell_name = spell_folder.replace('_', ' ')
    transcript = []

    audio_files = [f for f in os.listdir(spell_path) if f.endswith('.wav')]
    for audio_file in tqdm(audio_files, desc=f"[{spell_name}]", leave=False):
        audio_path = os.path.join(spell_path, audio_file)
        text = transcribe_audio(audio_path)
        transcript.append(text)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f'{spell_name}.txt')
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("\n".join(transcript))

def transcribe_all_audio():
    spell_folders = [f for f in os.listdir(INPUT_DIR) if os.path.isdir(os.path.join(INPUT_DIR, f))]

    with ThreadPoolExecutor() as executor:
        futures = [executor.submit(process_spell_folder, folder) for folder in spell_folders]
        for future in tqdm(as_completed(futures), total=len(futures), desc="All spells"):
            future.result()

if __name__ == '__main__':
    transcribe_all_audio()
