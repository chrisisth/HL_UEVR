import os
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import pyaudio
import vosk
import time
import json
from ilyxalogger import Logger, Colors
import keyboard
from inputs import get_gamepad
import threading
import random
from pydub import AudioSegment
from pydub.playback import play
import configparser
from pathlib import Path
Logger = Logger(write_to_logfile=True)

BASE_DIR = Path(__file__).resolve().parent

# Конфигурация путей к файлам
SPELLS_DATASETS_FOLDER = str(BASE_DIR / "HogwartsLegacy" / "SpellsDatasets")
VOSK_MODEL_PATH = str(BASE_DIR / "model" / "vosk-model-small-ru-0.22")
SETTINGS_CONFIG_PATH = str(BASE_DIR / "Settings" / "HogwartsLegacy" / "settings.ini")
FORBIDDEN_WORDS_LIST = str(BASE_DIR / "HogwartsLegacy" / "ForbiddenWords.txt")
PHRASES_LOG_FILE = str(BASE_DIR / "HogwartsLegacy" / "AdditionalPhrasesMapper.txt")

# Инициализация модели Vosk
if not os.path.exists(VOSK_MODEL_PATH):
    Logger.log_error(message=f"Модель не найдена в ${VOSK_MODEL_PATH}$")
    exit(1)

model = vosk.Model(VOSK_MODEL_PATH)

# Обнуление файлов при запуске
with open("Logger.log", "w", encoding="UTF-8") as file:
    file.write("")


# Настройка других параметров
config = configparser.ConfigParser(inline_comment_prefixes=('#'))
config.read(SETTINGS_CONFIG_PATH, encoding="UTF-8")

# Script Settings
PUSH_TO_TALK = config.getboolean("Script Settings", "PUSH_TO_TALK")
Logger.log_success(title="settings.ini", message=f"Значение PUSH_TO_TALK == ${PUSH_TO_TALK}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
INPUT_DEVICE = config.get("Script Settings", "INPUT_DEVICE").replace('"', '')
Logger.log_success(title="settings.ini", message=f"Значение INPUT_DEVICE == ${INPUT_DEVICE}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
SOUND_EFFECTS = config.getboolean("Script Settings", "SOUND_EFFECTS")
Logger.log_success(title="settings.ini", message=f"Значение SOUND_EFFECTS == ${SOUND_EFFECTS}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
USE_NE_MODEL = config.getboolean("Script Settings", "USE_NE_MODEL")
Logger.log_success(title="settings.ini", message=f"Значение USE_NE_MODEL == ${USE_NE_MODEL}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
OFF_BUTTON = config.get("Script Settings", "OFF_BUTTON").replace('"', '')
Logger.log_success(title="settings.ini", message=f"Значение OFF_BUTTON == ${OFF_BUTTON}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
PLAYER_GENDER = config.get("Script Settings", "PLAYER_GENDER").replace('"', '')
Logger.log_success(title="settings.ini", message=f"Значение PLAYER_GENDER == ${PLAYER_GENDER}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
PUSH_TO_TALK_BUTTON = config.get("Script Settings", "PUSH_TO_TALK_BUTTON").replace('"', '')
Logger.log_success(title="settings.ini", message=f"Значение PUSH_TO_TALK_BUTTON == ${PUSH_TO_TALK_BUTTON}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)

# Model Settings
MIN_CONFIDENCE = config.getfloat("Model Settings", "MIN_CONFIDENCE")
Logger.log_success(title="settings.ini", message=f"Значение MIN_CONFIDENCE == ${MIN_CONFIDENCE}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
MIN_PARTITIAL_CONFIDENCE = config.getfloat("Model Settings", "MIN_PARTITIAL_CONFIDENCE")
Logger.log_success(title="settings.ini", message=f"Значение MIN_PARTITIAL_CONFIDENCE == ${MIN_PARTITIAL_CONFIDENCE}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
FAIL_CONFIDENCE_SOUND = config.getfloat("Model Settings", "FAIL_CONFIDENCE_SOUND")
Logger.log_success(title="settings.ini", message=f"Значение FAIL_CONFIDENCE_SOUND == ${FAIL_CONFIDENCE_SOUND}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)


# Vosk Settings
FRAMES_PER_BUFFER = config.getint("Vosk Settings", "FRAMES_PER_BUFFER")
Logger.log_success(title="settings.ini", message=f"Значение FRAMES_PER_BUFFER == ${FRAMES_PER_BUFFER}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)
SAMPLERATE = config.getint("Vosk Settings", "SAMPLERATE")
Logger.log_success(title="settings.ini", message=f"Значение SAMPLERATE == ${SAMPLERATE}$ -> подгружено из settings.ini файла", bg_color=Colors.BG_GREEN)


# Конфигурация аудио-звуков
SOUNDS_CONFIG = {
    "ERRORS_SOUNDS": {
        "stats_file": str(BASE_DIR / "Settings" / "HogwartsLegacy" / "usage_stats_errors.json"),
        "sounds_folder": str(BASE_DIR / "Sounds" /"HogwartsLegacy" / "Error Sounds" / PLAYER_GENDER)
    },
    "UNKNOWNS_SPELLS_SOUNDS": {
        "stats_file": str(BASE_DIR / "Settings" / "HogwartsLegacy" / "usage_stats_unknown_spells.json"),
        "sounds_folder": str(BASE_DIR / "Sounds" /"HogwartsLegacy" / "Unknown spell phrases" / PLAYER_GENDER)
    },
    "NOT_ACTIVE_SPELLS_SOUNDS": {
        "stats_file": str(BASE_DIR / "Settings" / "HogwartsLegacy" / "usage_stats_not_active_spells.json"),
        "sounds_folder": str(BASE_DIR / "Sounds" /"HogwartsLegacy" / "Not active spell" / PLAYER_GENDER)
    },
    "TURN_OFF_SOUNDS": {
        "stats_file": str(BASE_DIR / "Settings" / "HogwartsLegacy" / "usage_stats_turn_off.json"),
        "sounds_folder": str(BASE_DIR / "Sounds" /"HogwartsLegacy" / "Turn Off Listening" / PLAYER_GENDER)
    },
    "TURN_ON_SOUNDS": {
        "stats_file": str(BASE_DIR / "Settings" / "HogwartsLegacy" / "usage_stats_turn_on.json"),
        "sounds_folder": str(BASE_DIR / "Sounds" /"HogwartsLegacy" / "Turn On Listening" / PLAYER_GENDER)
    },
}


for item in SOUNDS_CONFIG:
    if os.path.exists(SOUNDS_CONFIG[item]["stats_file"]):
        os.remove(SOUNDS_CONFIG[item]["stats_file"])
        Logger.log_info(message=f"Файл статистики ${SOUNDS_CONFIG[item]['stats_file']}$ удален.")


# Создаем объект для распознавания
rec = vosk.KaldiRecognizer(model, SAMPLERATE)

def play_random_sound(sounds_folder, stats_file):
    # Получаем список доступных звуков
    sound_files = [f for f in os.listdir(sounds_folder) if f.endswith(('.wav', '.mp3'))]

    # Инициализация или загрузка статистики
    if os.path.exists(stats_file):
        with open(stats_file, 'r', encoding='utf-8') as f:
            stats = json.load(f)
    else:
        stats = {}

    # Обновляем статистику: добавляем новые, убираем несуществующие
    for sound in sound_files:
        if sound not in stats:
            stats[sound] = 0
    stats = {sound: count for sound, count in stats.items() if sound in sound_files}

    if not stats:
        Logger.log_warning(message="Нет доступных звуков.")
        return

    # Выбираем звук с минимальным количеством воспроизведений
    min_count = min(stats.values())
    candidates = [s for s in stats if stats[s] == min_count]
    chosen_sound = random.choice(candidates)

    # Воспроизводим
    sound_path = os.path.join(sounds_folder, chosen_sound)
    sound = AudioSegment.from_wav(sound_path)
    play(sound)

    # Обновляем счётчик
    stats[chosen_sound] += 1

    # Сохраняем обновлённую статистику
    with open(stats_file, 'w', encoding='utf-8') as f:
        json.dump(stats, f, indent=2, ensure_ascii=False)

    Logger.log_success(f"Проигран звук: ${chosen_sound}$ (всего: {stats[chosen_sound]})")

def play_random_sound_in_thread(sounds_folder, stats_file):
    t = threading.Thread(target=play_random_sound, args=(sounds_folder, stats_file), daemon=True)
    t.start()

### Инициализация и обучение модели на датасетах ###
def load_dataset(folder_path):
    data = []
    labels = []

    for filename in os.listdir(folder_path):
        if filename.endswith(".txt"):
            spell_name = filename.replace(".txt", "")
            with open(os.path.join(folder_path, filename), encoding='utf-8') as f:
                lines = [line.strip().lower() for line in f.readlines() if line.strip()]
                data.extend(lines)
                labels.extend([spell_name] * len(lines))
    return data, labels

data, labels = load_dataset(SPELLS_DATASETS_FOLDER)

X_train, X_test, y_train, y_test = train_test_split(data, labels, test_size=0.2, random_state=42)

spells_model = Pipeline([
    ('tfidf', TfidfVectorizer(analyzer='char_wb', ngram_range=(2, 4))),
    ('clf', LogisticRegression(max_iter=1000))
])
spells_model.fit(X_train, y_train)

y_pred = spells_model.predict(X_test)

def predict_spell(phrase):
    probs = spells_model.predict_proba([phrase])[0]
    classes = spells_model.classes_
    top_index = probs.argmax()
    return classes[top_index], round(probs[top_index], 3)


### Основная часть управления + Vosk ###
if USE_NE_MODEL:
    MANUAL_NE_MODEL = {}
    all_datasets = os.listdir(SPELLS_DATASETS_FOLDER)
    for dataset in all_datasets:
        with open(f"{SPELLS_DATASETS_FOLDER}/{dataset}", "r", encoding="UTF-8") as file:
            data = file.read().split("\n")
        MANUAL_NE_MODEL[dataset.replace(".txt", "")] = [item for item in data if item]

with open(FORBIDDEN_WORDS_LIST, "r", encoding="UTF-8") as file:
    FORBIDDEN_WORDS = [item for item in file.read().split("\n") if item]

def check_before_ML(text):
    for spell in MANUAL_NE_MODEL:
        if text in MANUAL_NE_MODEL[spell]:
            return spell
    return ""

def toggle_listen_user(): # Keyboard
    global LISTEN_USER
    LISTEN_USER = not LISTEN_USER
    Logger.log_warning(f'Значение переменной $LISTEN_USER$ выставлено в ${LISTEN_USER}$')
    if SOUND_EFFECTS:
        if LISTEN_USER:
            play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["TURN_ON_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["TURN_ON_SOUNDS"]["stats_file"])
        else:
            play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["TURN_OFF_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["TURN_OFF_SOUNDS"]["stats_file"])

def monitor_gamepad():
    global push_to_talk_button_pressed
    ButtonCode = "BTN_TR" # По умолчанию
    if PUSH_TO_TALK_BUTTON == "LT":
        ButtonCode = "ABS_Z"
    elif PUSH_TO_TALK_BUTTON == "LB":
        ButtonCode = "BTN_TL"
    elif PUSH_TO_TALK_BUTTON == "RB":
        ButtonCode = "BTN_TR"

    while True:
        events = get_gamepad()
        for event in events:
            if event.code == ButtonCode and event.state == 1:  # RB нажат. event.state > 10  # значение > 10 — значит нажата
                push_to_talk_button_pressed = True  # Обработка нажатия RB. LT --> ABS_Z,   BTN_TL --> LB,   BTN_TR --> RB

def shoot_spell(buttons, delay=0.05, AdditionalSettings="NO_ADDITIONAL_SETTINGS", spell_name="", spell_active=True):
    global INPUT_DEVICE
    if INPUT_DEVICE == "Gamepad":
        if len(buttons) == 0 or not spell_active:
            if SOUND_EFFECTS:
                if not spell_active:
                    play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["NOT_ACTIVE_SPELLS_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["NOT_ACTIVE_SPELLS_SOUNDS"]["stats_file"])
                else:
                    play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["UNKNOWNS_SPELLS_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["UNKNOWNS_SPELLS_SOUNDS"]["stats_file"])
            Logger.log_warning(message=f"Заклинание ${spell_name}$ еще не изучено, либо сочетание клавиш не добавлено в конфигурацию")
            return

        global gamepad
        if AdditionalSettings == "NO_ADDITIONAL_SETTINGS":
            for button in buttons:
                gamepad.press_button(button=button)
                gamepad.update()
                time.sleep(0.05)  # Удержание кнопки 100 мс

                # Отпускание кнопки
                gamepad.release_button(button=button)
                gamepad.update()

        elif AdditionalSettings == "HOLD_RT":
            for button in buttons:
                # Нажатие RT (правого триггера)
                gamepad.right_trigger(value=255)  # Максимальное значение для полного нажатия
                gamepad.update()
                time.sleep(0.05)  # Удержание 50 мс

                # Нажатие кнопки
                gamepad.press_button(button=button)
                gamepad.update()
                time.sleep(0.05)  # Удержание 50 мс

                # Отпускание кнопки
                gamepad.release_button(button=button)
                gamepad.update()
                time.sleep(0.05)  # Удержание 50 мс

                # Отпускание RT
                gamepad.right_trigger(value=0)
                gamepad.update()

        elif AdditionalSettings == "JUST_CLICK_RT":
            # Нажатие RT (правого триггера)
            gamepad.right_trigger(value=255)  # Максимальное значение для полного нажатия
            gamepad.update()
            time.sleep(0.05)  # Удержание 100 мс

            # Отпускание RT
            gamepad.right_trigger(value=0)
            gamepad.update()

    elif INPUT_DEVICE == "Keyboard":
        if len(buttons) == 0 or not spell_active:
            if SOUND_EFFECTS:
                if not spell_active:
                    play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["NOT_ACTIVE_SPELLS_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["NOT_ACTIVE_SPELLS_SOUNDS"]["stats_file"])
                else:
                    play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["UNKNOWNS_SPELLS_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["UNKNOWNS_SPELLS_SOUNDS"]["stats_file"])
            Logger.log_warning(message=f"Заклинание ${spell_name}$ еще не изучено, либо сочетание клавиш не добавлено в конфигурацию")
            return
        for button in buttons:
            if button:
                keyboard.press_and_release(button)
                # Logger.log_success(f"Нажата клавиша ${button}$")
                time.sleep(delay)

# Инициализация микрофона
p = pyaudio.PyAudio()
stream = p.open(format=pyaudio.paInt16,
                channels=1,
                rate=SAMPLERATE,
                input=True,
                frames_per_buffer=FRAMES_PER_BUFFER)
stream.start_stream()


# Настраиваем под конкретное устройство INPUT_DEVICE + функционал PUSH_TO_TALK (работает только для геймпада)
push_to_talk_button_pressed = True
if INPUT_DEVICE == "Gamepad":
    import vgamepad as vg
    # Создание виртуального геймпада
    gamepad = vg.VX360Gamepad()
    from Settings.HogwartsLegacy.Xbox_SPELLS_KEYS import SPELLS_KEYS
    if PUSH_TO_TALK:
        push_to_talk_button_pressed = False
        gamepad_thread = threading.Thread(target=monitor_gamepad, daemon=True)
        gamepad_thread.start()

elif INPUT_DEVICE == "Keyboard":
    from Settings.HogwartsLegacy.Keyboard_SPELLS_KEYS import SPELLS_KEYS

if OFF_BUTTON:
        keyboard.add_hotkey(OFF_BUTTON, toggle_listen_user)

LISTEN_USER = True
Logger.log_success(message=f"Скрипт инициализирован успешно")
execution_time = ""
iteration_started_flag = False
while True:
    if LISTEN_USER:
        if push_to_talk_button_pressed:
            data = stream.read(FRAMES_PER_BUFFER, exception_on_overflow=False)

            # Итоговый результат
            if rec.AcceptWaveform(data): 
                result = json.loads(rec.Result())
                if len(result['text']) > 0:
                    if result['text'] in FORBIDDEN_WORDS:
                        Logger.log_error(message=f"Слово ${result['text']}$ находится в списке $запрещенных$ слов")
                        if iteration_started_flag:
                            iteration_started_flag = False
                        rec.Reset()
                        continue

                    spell, confidence = predict_spell(result['text'])
                    if float(confidence) < MIN_CONFIDENCE:
                        if iteration_started_flag:
                            execution_time = f"{time.time() - iteration_start_time:.2f}"
                        else:
                            execution_time = "0.00"
                        iteration_started_flag = False

                        Logger.log_error(f"[{execution_time} sec] Распознано: ${result['text']}$. SPELL: $Nothing$ (вероятность ${round(float(confidence)*100, 2)}%$ (могло быть ${spell}$))")
                        if float(confidence) > FAIL_CONFIDENCE_SOUND and SOUND_EFFECTS:
                            play_random_sound_in_thread(sounds_folder=SOUNDS_CONFIG["ERRORS_SOUNDS"]["sounds_folder"], stats_file=SOUNDS_CONFIG["ERRORS_SOUNDS"]["stats_file"])
                        if PUSH_TO_TALK:
                            push_to_talk_button_pressed = False
                        rec.Reset()
                    else:
                        if iteration_started_flag:
                            execution_time = f"{time.time() - iteration_start_time:.2f}"
                        else:
                            execution_time = "0.00"
                        iteration_started_flag = False

                        Logger.log_success(f"[{execution_time} sec] Распознано: ${result['text']}$. SPELL: ${spell}$, вероятность ${round(float(confidence)*100, 2)}%$")
                        shoot_spell(buttons=SPELLS_KEYS[spell][0], delay=SPELLS_KEYS[spell][1], AdditionalSettings=SPELLS_KEYS[spell][2], spell_name=spell, spell_active=SPELLS_KEYS[spell][3])
                        with open(PHRASES_LOG_FILE, "r", encoding="UTF-8") as file:
                            tmp_list = [item.split(" --> ")[1] for item in file.read().split("\n") if item]
                        with open(PHRASES_LOG_FILE, "a", encoding="UTF-8") as file:
                            if not result['text'] in tmp_list:
                                file.write(f"{spell} --> {result['text']} --> {round(float(confidence)*100, 2)}%\n")
                        rec.Reset()
                        if PUSH_TO_TALK:
                            push_to_talk_button_pressed = False

            # Частичный результат  
            else:   
                partial_result = rec.PartialResult() 
                partial_json = json.loads(partial_result)
                # if len(partial_json['partial'].split(" ")) > 4:
                #     rec.Reset()
                if len(partial_json['partial']) > 0:
                    #print(f"Частичный результат: {partial_json['partial']}")
                    if not iteration_started_flag:
                        iteration_started_flag = True
                        iteration_start_time = time.time()
                    spell = ""
                    if USE_NE_MODEL:
                        spell = check_before_ML(text=partial_json['partial'])

                    if spell:
                        if len(spell.split(" ")) > 1:
                            continue
                        if iteration_started_flag:
                            execution_time = f"{time.time() - iteration_start_time:.2f}"
                        else:
                            execution_time = "0.00"
                        iteration_started_flag = False
                        
                        Logger.log_success(f"[{execution_time} sec] Частично распознано: ${partial_json['partial']}$. SPELL: ${spell}$ - Подбор по словам")
                        shoot_spell(buttons=SPELLS_KEYS[spell][0], delay=SPELLS_KEYS[spell][1], AdditionalSettings=SPELLS_KEYS[spell][2], spell_name=spell, spell_active=SPELLS_KEYS[spell][3])
                        rec.Reset()
                        if PUSH_TO_TALK:
                            push_to_talk_button_pressed = False
                    else:
                        spell, confidence = predict_spell(partial_json['partial'])
                        if float(confidence) > MIN_PARTITIAL_CONFIDENCE:
                            if len(spell.split(" ")) > 1:
                                continue
                            if iteration_started_flag:
                                execution_time = f"{time.time() - iteration_start_time:.2f}"
                            else:
                                execution_time = "0.00"
                            iteration_started_flag = False
                            
                            Logger.log_success(f"[{execution_time} sec] Частично распознано: ${partial_json['partial']}$. SPELL: ${spell}$, вероятность ${round(float(confidence)*100, 2)}%$")
                            shoot_spell(buttons=SPELLS_KEYS[spell][0], delay=SPELLS_KEYS[spell][1], AdditionalSettings=SPELLS_KEYS[spell][2], spell_name=spell, spell_active=SPELLS_KEYS[spell][3])
                            rec.Reset()
                            if PUSH_TO_TALK:
                                push_to_talk_button_pressed = False
    else:
        time.sleep(0.1)  # Задержка когда прослушивание выключено, чтобы не нагружать CPU
