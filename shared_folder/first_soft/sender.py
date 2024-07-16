import socket
import time

# Создаем сокет
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Привязываем сокет к IP-адресу и порту
server_address = ('192.168.56.10', 8000)
sock.bind(server_address)

# Начинаем прослушивать входящие соединения
sock.listen(1)

# Счетчик
cnt = 0

# Открываем файл для записи логов
log_file = open('/vagrant/shared_folder/sender.log', 'a')

log_file.write("[SENDER] Script started\n")
log_file.flush()

while True:
    try:
        # Ждем входящего соединения
        log_file.write("[SENDER] Waiting for a connection...\n")
        log_file.flush()

        connection, client_address = sock.accept()

        try:
            log_file.write(f'Connection from {client_address}\n')

            # Увеличиваем счетчик
            cnt += 1

            # Отправляем значение счетчика на vm2
            connection.sendall(str(cnt).encode())

        finally:
            # Очищаем входящее соединение
            connection.close()

        # Ждем 5 секунд перед следующей итерацией
        time.sleep(5)
    
    except Exception as e:
        log_file.write(f"[SENDER] Exception: {e}\n")
        log_file.flush()

# Закрываем файл логов
log_file.close()
