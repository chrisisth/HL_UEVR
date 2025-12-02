import vgamepad as vg

A= vg.XUSB_BUTTON.XUSB_GAMEPAD_A
B= vg.XUSB_BUTTON.XUSB_GAMEPAD_B
X= vg.XUSB_BUTTON.XUSB_GAMEPAD_X
Y= vg.XUSB_BUTTON.XUSB_GAMEPAD_Y
LB= vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER
RB= vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER
BACK= vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK
START= vg.XUSB_BUTTON.XUSB_GAMEPAD_START
LS= vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB # Left Stick вжать
RS= vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB # Right Stick вжать
UP= vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP
DOWN= vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN
LEFT= vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT
RIGHT= vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT
GUIDE_BBUTTON= vg.XUSB_BUTTON.XUSB_GAMEPAD_GUIDE

# Схема:
# "Название заклинания":(["Кнопка_1", "Кнопка_2"], Задержка_между_нажатиями_кнопок, "Дополнительные настройки", Активно ли заклинание)
# Дополнительные настройки:
#   "NO_ADDITIONAL_SETTINGS" - без доп. параметров
#   "JUST_CLICK_RT" - опция нужно только для использования заклинания Редукто, т.к. вызывается не нажатием кнопки, а кликом RT, который является методом
#   "HOLD_RT" - опция, при которой все нажатия заданных кнопок сопровождаются зажатием RT. 
# Опция HOLD_RT explanation: Нажать RT, чтобы выбрать коллекцию заклинаний, с зажатым RT нажать стрелочкку вправо, сменив коллекцию, с зажатым RT нажать X, чтобы вызывать заклинание

SPELLS_KEYS = {
    # Основные заклинания
    "Редукто":([""], 0.05, "JUST_CLICK_RT", True), # No buttons, cause RT is a method, not button
    "Ревелио":([LEFT], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Протего":([Y], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Петрификус Тоталус":([X], 0.05, "NO_ADDITIONAL_SETTINGS", True),


    # Заклинаниия группы 1 (Активатор RT+Стрелка вверх)
    "Делюминейт":([UP, Y], 0.05, "HOLD_RT", True),
    "Левиосо":([UP, B], 0.05, "HOLD_RT", True),
    "Акцио":([UP, X], 0.05, "HOLD_RT", True),
    "Экспеллиармус":([UP, A], 0.05, "HOLD_RT", True),


    # Заклинаниия группы 2 (Активатор RT+Стрелка вправо)
    "Люмос":([RIGHT, Y], 0.05, "HOLD_RT", True),
    "Инсендио":([RIGHT, A], 0.05, "HOLD_RT", True),
    "Депульсо":([RIGHT, X], 0.05, "HOLD_RT", True),


    # Заклинаниия группы 3 (Активатор RT+Стрелка вниз)
    "Репаро":([DOWN, Y], 0.05, "HOLD_RT", True),
    "Конфринго":([DOWN, A], 0.05, "HOLD_RT", True),
    "Диффиндо":([DOWN, X], 0.05, "HOLD_RT", True),


    # Не изучены
    "Арресто Моментум":([], 0.05, "", True),
    "Глациус":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Трансформация":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Десцендо":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Флиппендо":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Бомбарда":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Вингардиум Левиоса":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Авада Кедавра":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Круцио":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Империо":([], 0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Алохомора":([], 0.05, "NO_ADDITIONAL_SETTINGS", True)
}