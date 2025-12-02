import torch
from pydub import AudioSegment
import numpy as np
from pydub import AudioSegment
from pydub.playback import play
import os
import re
import shutil

def get_next_filename(base_name='kseniya', ext='wav', folder='.'):
    max_index = 0
    pattern = re.compile(rf"{re.escape(base_name)}_(\d+)\.{ext}")
    for filename in os.listdir(folder):
        match = pattern.match(filename)
        if match:
            index = int(match.group(1))
            max_index = max(max_index, index)
    return f"{base_name}_{max_index + 1}.{ext}"

# Загрузка модели
device = torch.device('cpu')
model, example_text = torch.hub.load(repo_or_dir='snakers4/silero-models',
                                     model='silero_tts',
                                     language='ru',
                                     speaker='v3_1_ru',
                                     trust_repo=True)

# ['aidar', 'baya', 'kseniya', 'xenia', 'eugene', 'random']
# Текст и параметры 
speaker = 'kseniya'

audios = os.listdir("generated_audios")
for audio in audios:
    os.remove(f"generated_audios/{audio}")

while True:
    text = input("Введите фразу: ")
    speed = 1.05
    loudness = 0.3
    audio_path = f'generated_audios/kseniya.wav'

    # Генерация аудио
    model.save_wav(text=text,
                   speaker=speaker,
                   sample_rate=48000,
                   audio_path=audio_path)

    # Загрузка и обработка
    audio = AudioSegment.from_wav(audio_path)

    # Изменение скорости
    new_sample_rate = int(audio.frame_rate * speed)
    audio = audio._spawn(audio.raw_data, overrides={'frame_rate': new_sample_rate})

    # Изменение громкости
    audio = audio + (20 * np.log10(loudness))

    # Добавление тишины 0.25 секунды
    silence = AudioSegment.silent(duration=250)
    audio = silence + audio

    # Сохраняем финальный результат
    audio_path = "generated_audios/" + get_next_filename(folder="generated_audios")
    audio.export(audio_path, format='wav')

    sound = AudioSegment.from_wav(audio_path)
    play(sound)

    folders = os.listdir("../Sounds/HogwartsLegacy/")
    print("Выберите параметр:")
    for i in range(len(folders)):
        print(f"[{i}] - {folders[i]} (сохранить)")
    print(f"[{len(folders)}] - не сохранять")

    current_answer = False
    while not current_answer:
        try:
            answer = int(input(">"))
            current_answer = True
        except ValueError as error:
            print("[ValueError]: !!! В ОТВЕТ НУЖНО УКАЗАТЬ ЧИСЛО !!!")

    if answer >= len(folders):
        continue
    else:
        dest_sound = get_next_filename(base_name="sound", folder=f"../Sounds/HogwartsLegacy/{folders[answer]}/")
        shutil.copy(audio_path, f"../Sounds/HogwartsLegacy/{folders[answer]}/{dest_sound}")