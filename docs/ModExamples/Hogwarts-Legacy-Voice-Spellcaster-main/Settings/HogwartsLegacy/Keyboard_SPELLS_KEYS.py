# Схема:
# "Название заклинания":(["Кнопка_1", "Кнопка_2"], Задержка_между_нажатиями_кнопок, "Дополнительные настройки", Активно ли заклинание)
# В режиме вводе с клавиатуры Дополнительные настройки не применяются и по умолчанию всегда = "NO_ADDITIONAL_SETTINGS"

SPELLS_KEYS = {
    # Основные заклинания
    "Петрификус Тоталус":(["f"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Редукто":(["F5"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Ревелио":(["r"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Протего":(["q"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Алохомора":(["f"],0.05, "NO_ADDITIONAL_SETTINGS", True),


    # Заклинаниия группы 1 (Активатор-Кнопка 5)52
    "Левиосо":(["5", "2"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Акцио":(["5", "4", "4"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Экспеллиармус":(["5", "3"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Делюминейт":(["5", "1"],0.05, "NO_ADDITIONAL_SETTINGS", True),


    # Заклинаниия группы 2 (Активатор-Кнопка 6)
    "Инсендио":(["6", "3"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Люмос":(["6", "1"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Депульсо":(["6", "4"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Глациус":(["6", "2"],0.05, "NO_ADDITIONAL_SETTINGS", True),


    # Заклинаниия группы 3 (Активатор-Кнопка 7)
    "Конфринго":(["7", "3"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Репаро":(["7", "1"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Флиппендо":(["7", "4"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Арресто Моментум":(["7", "2"],0.05, "NO_ADDITIONAL_SETTINGS", True),

    # Заклинаниия группы 4 (Активатор-Кнопка 8)
    "Вингардиум Левиоса":(["8", "1"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Диффиндо":(["8", "3"],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Десцендо":(["8", "4"],0.05, "NO_ADDITIONAL_SETTINGS", True),

    "Трансформация":([],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Бомбарда":([],0.05, "NO_ADDITIONAL_SETTINGS", True),
    
    "Авада Кедавра":([],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Круцио":([],0.05, "NO_ADDITIONAL_SETTINGS", True),
    "Империо":([],0.05, "NO_ADDITIONAL_SETTINGS", True)
}