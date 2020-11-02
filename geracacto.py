x = 5


def geracacto(altura):  # altura deve ser uma potência de 2
    global x
    bit = x & 1  # AND bit a bit
    x = x >> 1  # Shift para a direita
    if bit:
        x = x ^ 0xb400  # altera potencialmente qualquer bit de x

    if x < 62258:  # o intervalo [0, 62258] abrange aproximadamente 95% dos
        return 0  # valores representáveis com 16 bits.

    # garante que o valor retornado pertence ao intervalo [1, altura].
    # x & (altura - 1) = mod(x, altura), quando altura é uma potência de 2.
    # Porquê?
    return (x & (altura - 1)) + 1


for i in range(100):
    print(geracacto(4), hex(x))
