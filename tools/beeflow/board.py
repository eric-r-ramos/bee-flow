"""Modelo de tabuleiro do Bee Flow.

Compartilhado pelo gerador e pelo solver. A regra central mora aqui:
um bloco so e coletavel se estiver na *fronteira*, ou seja, ligado ao lado
de fora da imagem por um caminho de celulas vazias (vizinhanca de 4).
Bloco ilhado no miolo nao existe pro jogo ate os vizinhos sairem.
"""

from __future__ import annotations

from collections import deque

EMPTY = "."


class Board:
    __slots__ = ("rows", "cols", "cells")

    def __init__(self, rows: int, cols: int, cells: list[str]):
        if len(cells) != rows * cols:
            raise ValueError(f"esperava {rows * cols} celulas, recebi {len(cells)}")
        self.rows = rows
        self.cols = cols
        self.cells = cells

    # ---------------------------------------------------------------- criacao

    @classmethod
    def from_lines(cls, lines: list[str]) -> "Board":
        lines = [ln.rstrip("\n") for ln in lines if ln.strip("\n") != ""]
        cols = max(len(ln) for ln in lines)
        padded = [ln.ljust(cols, EMPTY) for ln in lines]
        cells = [ch for ln in padded for ch in ln]
        return cls(len(padded), cols, cells)

    def clone(self) -> "Board":
        return Board(self.rows, self.cols, list(self.cells))

    def to_lines(self) -> list[str]:
        return [
            "".join(self.cells[r * self.cols:(r + 1) * self.cols])
            for r in range(self.rows)
        ]

    # ------------------------------------------------------------- consultas

    def idx(self, r: int, c: int) -> int:
        return r * self.cols + c

    def rc(self, i: int) -> tuple[int, int]:
        return divmod(i, self.cols)

    def filled(self) -> int:
        return sum(1 for ch in self.cells if ch != EMPTY)

    def is_clear(self) -> bool:
        return self.filled() == 0

    def counts_by_color(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for ch in self.cells:
            if ch != EMPTY:
                out[ch] = out.get(ch, 0) + 1
        return out

    def state_key(self) -> str:
        return "".join(self.cells)

    # ------------------------------------------------------------- fronteira

    def _outside_mask(self) -> bytearray:
        """Celulas vazias alcancaveis a partir da borda do grid."""
        mask = bytearray(self.rows * self.cols)
        queue: deque[int] = deque()

        for c in range(self.cols):
            for r in (0, self.rows - 1):
                i = self.idx(r, c)
                if self.cells[i] == EMPTY and not mask[i]:
                    mask[i] = 1
                    queue.append(i)
        for r in range(self.rows):
            for c in (0, self.cols - 1):
                i = self.idx(r, c)
                if self.cells[i] == EMPTY and not mask[i]:
                    mask[i] = 1
                    queue.append(i)

        while queue:
            i = queue.popleft()
            r, c = self.rc(i)
            for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if 0 <= nr < self.rows and 0 <= nc < self.cols:
                    j = self.idx(nr, nc)
                    if not mask[j] and self.cells[j] == EMPTY:
                        mask[j] = 1
                        queue.append(j)
        return mask

    def frontier(self) -> list[int]:
        """Indices dos blocos coletaveis agora."""
        mask = self._outside_mask()
        out: list[int] = []
        for i, ch in enumerate(self.cells):
            if ch == EMPTY:
                continue
            r, c = self.rc(i)
            for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if not (0 <= nr < self.rows and 0 <= nc < self.cols):
                    out.append(i)  # encosta na borda do grid: fronteira
                    break
                if mask[self.idx(nr, nc)]:
                    out.append(i)
                    break
        return out

    def frontier_by_color(self) -> dict[str, list[int]]:
        out: dict[str, list[int]] = {}
        for i in self.frontier():
            out.setdefault(self.cells[i], []).append(i)
        return out

    def remove(self, i: int) -> None:
        self.cells[i] = EMPTY
