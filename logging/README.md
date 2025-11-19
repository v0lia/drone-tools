# Create log folder

Проект состоит из двух файлов:
- **create_log_folder.sh**
- **create_log_folder.service**

## РАБОТА СКРИПТА
Скрипт **create_log_folder.sh** при запуске создаёт папку вида *~/logs/index_timestamp_log-name*, где:  
*index* - возрастающее целое неотрицательное (0, 1, 2, ..., N),  
*timestamp* - дата-время в формате ГГГГ-ММ-ДД_ЧЧ-ММ-СС,  
*log-name* - имя лога, переданное пользователем при вызове скрипта (опционально).  
- При отсутствии переданного *log-name* будет присвоен "default_log_name".  
- При передаче пользовательский *log-name* будет очищен от недопустимых символов (допустимо: `[a-zA-Z0-9-_]`, то есть латинские буквы, арабские цифры и символы "-" и "_").  
- Если после очистки *log-name* становится пустым, присваивается "not_empty_log_name".

## ПРИМЕРЫ ВЫЗОВА СКРИПТА 
```./create_log_folder.sh```  
```./create_log_folder.sh logname_A``` 

## ВХОД И ВЫХОД
Скрипт получает на входе *log-name* и создаёт папку для логов.  
Путь к созданной папке сохраняется в 2 файла в каталоге `/tmp`:
- `/tmp/log_folder_path` содержит **только путь к папке**, например: "`home/username/logs/0000_2025-12-31_23_59_59`"
- `/tmp/log_folder_path.env` содержит **shell-код**, пригодный для `source`, например: ```export LOG_FOLDER_PATH="home/username/logs/0000_2025-12-31_23_59_59"```
### Получение результата
После выполнения скрипта путь к папке можно считать любым из двух способов:
- ```LOG_FOLDER_PATH=$(< /tmp/log_folder_path)```
- ```source /tmp/log_folder_path.env```  

Также можно настроить автосчитывание переменной `LOG_FOLDER_PATH` из файла `/tmp/log_folder_path.env` при запуске приложений, дополнив файл `.bashrc`. Для этого выполните:  
```./add_to_bashrc.sh```

### *Примечание* 
Файлы в `/tmp` удаляются при перезагрузке ОС. Новую папку для логов предполагается создавать как минимум раз в сессию.

## **СЕРВИС**
Запуск скрипта можно автоматизировать через сервис **create_log_folder.service**, который вызывает скрипт один раз при загрузке ОС.  
Таким образом, вместе работающий сервис и запускаемый им скрипт обеспечат создание одной папки логов для каждой загрузки ОС.

### Установка сервиса:
```mkdir -p ~/.config/systemd/user/```  
```cp create_log_folder.service ~/.config/systemd/user/```  
```systemctl --user daemon-reexec```  
```systemctl --user daemon-reload```  
```systemctl --user enable create_log_folder.service```  
```systemctl --user start create_log_folder.service```

### Деинсталляция сервиса:
```systemctl --user disable --now create_log_folder.service```  
```systemctl --user daemon-reload```  
```rm ~/.config/systemd/user/create_log_folder.service```  

## *ПРИМЕЧАНИЕ*
Скрипт создаёт новую папку и сохраняет новый путь **при каждом запуске**, включая:
- автозапуск при загрузке ОС с помощью сервиса;
- ручной запуск.
