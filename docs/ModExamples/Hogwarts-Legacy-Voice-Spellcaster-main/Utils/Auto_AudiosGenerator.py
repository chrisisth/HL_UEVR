import torch
from pydub import AudioSegment
import numpy as np
import os
import re
import shutil
from pathlib import Path
from ilyxalogger import Logger
Logger = Logger(write_to_logfile=False)

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent
SOUNDS_DIR = PROJECT_ROOT /  "Sounds" / "HogwartsLegacy"

SOUNDS = {
    "Error Sounds": {
        "Path": SOUNDS_DIR / "Error Sounds",
        "Description":"Звуковой эффект, когда нет достаточной уверенности, что пользователь назвал корректно заклинание. Пример: вместо заклинания Акцио - модель распознала слово Актиния. При этом, модель не может точно сказать, что слово Актиния можно отнести к заклинанию Акцио, в следствие чего срабатывает звук неудачи. Звук срабатывает при условии заданных параметров. В settings.ini выставляется параметры MIN_CONFIDENCE и FAIL_CONFIDENCE_SOUND. Если точность определения выше FAIL_CONFIDENCE_SOUND, но ниже MIN_CONFIDENCE, то включается звуковой эффект неудачи.",
        "Phrases": ["Блин, не сработало", "Да блин, не сработало", "Что я делаю не так?", 
                    "Произносить нужно чётче", "Да что же это такое?", "Всё как в тумане",
                    "Кажется палочка не поняла, что я имею ввиду", "Абракадабра какая-то получается",
                    "Кажется это неправильное произношение заклинания"]
    },
    "Not active spell": {
        "Path": SOUNDS_DIR / "Not active spell",
        "Description":"Звуковой эффект, когда распознанное заклинание неактивно. Активность заклинаний настраивается в конфигурации кнопок. Нужно на ранних стадиях игры, когда у вас открыта только одна панель заклинаний. Для чего нужно? - Если у вас не открыты коллекции панелей заклинаний (эта возможность открывается по мере прохождения), и если у вас два заклинания прикреплены на одной и той же кнопке - вы можете выбрать какое из них будет активно в данный момент.",
        "Phrases": ["Я пока новичок, и не могу использовать такое количество заклинаний", "Я хоть и знаю это заклинание, но использовать его не могу",
                    "У меня не хватает слотов для использования этого заклинания", "Не то, чтобы я этого заклинания не знаю, но что-то здесь не так",
                    "Когда я буду могущественным волшебником - я смогу использовать все эти заклинания", 
                    "Пока что моя магия не так сильна, чтобы использовать такое количество заклинаний", "Вместо этого заклинания, у меня в голове почему-то другое", "Если я хочу использовать это заклинание - нужно перестать использовать другое"]
    },
    "Turn Off Listening": {
        "Path": SOUNDS_DIR / "Turn Off Listening",
        "Description":"Звуковой эффект, оповещающий о том, что скрипт остановил прослушивание пользователя после нажатия OFF_BUTTON",
        "Phrases": ["Закрываю ушки", "Больше слушать не буду", "Заканчиваю слушать", "Подслушивать больше не буду", "Всё. Больше не слушаю", "Больше я слушать не намереваюсь"]
    },
    "Turn On Listening": {
        "Path": SOUNDS_DIR / "Turn On Listening",
        "Description":"Звуковой эффект, оповещающий о том, что скрипт возобновил прослушивание пользователя после нажатия OFF_BUTTON",
        "Phrases": ["Открываю ушки", "Я теперь опять слышу", "А вот и снова я, подслушиваю всё, что ты говоришь", "И снова я вас подслушиваю", "Да. Теперь я опять слушаю вас", "Я снова могу слушать"]
    },
    "Unknown spell phrases": {
        "Path": SOUNDS_DIR / "Unknown spell phrases",
        "Description":"Звуковой эффект, который оповещает пользователя о том, что данное заклинание еще не изучено. Если в конфигурации заклинаний не заданы кнопки для заклинания (пустой список), то активируется данный звуковой эффект",
        "Phrases": ["Может стоит прочитать про это заклинание в книгах", "Похоже этого заклинания я еще не знаю", "Этому заклинанию меня еще не обучали", 
                    "Я еще не умею применять это заклинание", "Профессор Фиг, меня этому ещё не учил", "Надо спросить у профессора Уизли как использовать это заклинание", "Может Себастьян поможет мне выучить это заклинание", "Можно поспрашивать учителей, что это за заклинание",
                    "С этим заклинанием я еше управляться не умею", "Как-нибудь надо его изучить"]
    }
}


def get_next_filename(base_name='kseniya', ext='wav', folder='.'):
    max_index = 0
    pattern = re.compile(rf"{re.escape(base_name)}_(\d+)\.{ext}")
    for filename in os.listdir(folder):
        match = pattern.match(filename)
        if match:
            index = int(match.group(1))
            max_index = max(max_index, index)
    return f"{base_name}_{max_index + 1}.{ext}"

def remove_wav_files(root_folder):
    for dirpath, dirnames, filenames in os.walk(root_folder):
        for file in filenames:
            if file.lower().endswith('.wav'):
                full_path = os.path.join(dirpath, file)
                try:
                    os.remove(full_path)
                    #print(f"Удалён файл: {full_path}")
                except Exception as e:
                    print(f"Ошибка при удалении {full_path}: {e}")

# Загрузка модели
# ['aidar', 'baya', 'kseniya', 'xenia', 'eugene', 'random']
device = torch.device('cpu')
model, example_text = torch.hub.load(repo_or_dir='snakers4/silero-models',
                                     model='silero_tts',
                                     language='ru',
                                     speaker='v3_1_ru',
                                     trust_repo=True)

speakers = [("kseniya", "Female"), ("eugene", "Male")]

remove_wav_files(SOUNDS_DIR)
Logger.log_success(message=f"Директория ${SOUNDS_DIR}$ очищена")

for speaker_tuple in speakers:
    speaker, gender = speaker_tuple[0], speaker_tuple[1]
    for item in SOUNDS:
        Folder = SOUNDS[item]["Path"] / gender
        Phrases = SOUNDS[item]["Phrases"]
        for phrase in Phrases:
            if gender == "Male":
                speed = 1.05
            else:
                speed = 1.05
            loudness = 0.3
            audio_path = str(Path("generated_audios") / f"tmp_{speaker}.wav")

            # Генерация аудио
            model.save_wav(text=phrase,
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
            audio_path = str(Path("generated_audios") / get_next_filename(folder="generated_audios", base_name=speaker))
            audio.export(audio_path, format='wav')

            folders = os.listdir(SOUNDS_DIR)
            dest_sound = get_next_filename(base_name=f"{speaker}_sound", folder=Folder)
            shutil.copy(audio_path, Folder / dest_sound)
            Logger.log_success(message=f"Файл сохранен в ${Folder / dest_sound}$")


Logger.log_success(message="Программа завершена")
remove_wav_files("generated_audios")
Logger.log_success(message=f"Директория ${SOUNDS_DIR}$ очищена")