import socket
import logging
import sys

# Создаем сокет
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Адрес сервера на vm1
server_address = ('192.168.56.10', 8000)

# Устанавливаем счетчик для 12 итераций
iteration_count = 0
max_iterations = 10

# Открываем файл для записи логов
log_file = open('/vagrant/shared_folder/receiver.log', 'a')

log_file.write("[RECEIVER] Script started\n")
log_file.flush()

while iteration_count < max_iterations:
    try:
        # Подключаемся к серверу на vm1
        sock.connect(server_address)

        # Получаем данные от vm1
        data = sock.recv(1024)

        if not data:
            break

        # Декодируем данные из байтов в строку
        value = int(data.decode())

        # Умножаем значение на 10 и выводим в терминал
        result = value * 10
        print(f'[RECEIVER] Received value: {value}, result: {result}')

        log_file.write(f'[RECEIVER] Received value: {value}, result: {result}\n')
        log_file.flush()

        # Увеличиваем счетчик итераций
        iteration_count += 1
        
        print(f"---------------------------------------------\n\n")
        
        log_file.write("---------------------------------------------\n\n")
        log_file.flush()

    finally:
        # Закрываем соединение после получения данных
        sock.close()

        # Создаем новый сокет для следующей итерации
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Закрываем файл логов
log_file.close()
