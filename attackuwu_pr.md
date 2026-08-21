# AttackUwu PR

## RU

Добавлена игра `BIRDS` для x16-PRos на основе механики Flappy Birds.
Пользователь управляет вертикальным перемещением птицы с помощью `Space` и
проходит через промежутки между трубами. За каждую пройденную трубу начисляется
одно очко. Столкновение с трубой или границей игрового поля завершает раунд.
Клавиша `R` запускает новый раунд, `Esc` завершает программу.

Команда `BIRDS` добавлена в экран HELP, встроенный список команд ядра и систему
автодополнения. В `build-linux.sh` добавлены проверка зависимостей и компиляция
`BIRDS.BIN`. `run-linux.sh` проверяет наличие дисковых образов и использует
явное указание формата `raw` для QEMU.

## ES

Se ha añadido el juego `BIRDS` para x16-PRos, basado en la mecánica de Flappy
Birds. El usuario controla el movimiento vertical del pájaro con `Space` y
atraviesa los espacios entre las tuberías. Se otorga un punto por cada tubería
superada. Una colisión con una tubería o con el límite del campo termina la
partida. `R` inicia una nueva partida y `Esc` finaliza el programa.

El comando `BIRDS` se ha añadido a HELP, a la lista integrada de comandos del
kernel y al sistema de autocompletado. `build-linux.sh` comprueba las
dependencias y compila `BIRDS.BIN`. `run-linux.sh` verifica las imágenes de
disco y especifica explícitamente el formato `raw` para QEMU.

## EN

The `BIRDS` game has been added to x16-PRos using Flappy Birds-style mechanics.
The player controls the bird's vertical movement with `Space` and navigates
through pipe gaps. One point is awarded for each pipe successfully passed. A
collision with a pipe or the playfield boundary ends the round. `R` starts a
new round and `Esc` exits the program.

The `BIRDS` command has been added to HELP, the kernel's built-in command list,
and the autocomplete system. `build-linux.sh` now checks dependencies and
compiles `BIRDS.BIN`. `run-linux.sh` verifies that disk images exist and
explicitly sets the QEMU image format to `raw`.

Author: AttackUwu - https://github.com/attackuwu/
