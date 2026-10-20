#!/usr/bin/env python3
"""Демонстрация бинарной анатомии safetensors vs pickle.

Запускается на стандартной библиотеке Python без внешних зависимостей:
1. Показывает, как устроен эксплойт __reduce__ в pickle (безопасная симуляция).
2. Собирает валидный бинарный файл .safetensors и парсит его заголовок
   за доли миллисекунды, не загружая сами тензоры в RAM.
"""

import array
import json
import pickle
import struct
import tempfile
from pathlib import Path


class SafeDemoExploit:
    """Демонстрация того, как pickle выполняет код в момент загрузки."""

    def __reduce__(self):
        # В реальной атаке здесь стоит os.system("curl ... | sh").
        # Мы вызываем безопасный print, чтобы наглядно увидеть момент срабатывания.
        return (
            print,
            ("  [!] СРАБОТАЛ __reduce__ ВНУТРИ pickle.loads() ДО вызова predict()!",),
        )


def demo_pickle_danger() -> None:
    print("=== 1. Почему формат pickle (.pkl / .pt) опасен (RCE при загрузке) ===")
    payload = pickle.dumps({"weights": [1.0, 2.0], "hook": SafeDemoExploit()})
    print(f"  Размер сериализованного pickle-блоба: {len(payload)} байт")
    print("  Вызываем pickle.loads(payload)...")
    _ = pickle.loads(payload)
    print("")


def create_minimal_safetensors(file_path: Path) -> None:
    """Создаёт бинарно валидный файл формата .safetensors."""
    # Два тензора float32: матрица эмбеддингов [4, 3] (48 байт) и вектор bias [3] (12 байт)
    emb_bytes = array.array("f", [0.1 * i for i in range(12)]).tobytes()
    bias_bytes = array.array("f", [0.01, -0.02, 0.05]).tobytes()

    header_dict = {
        "__metadata__": {
            "format": "pt",
            "project": "personal_docs_vault_router",
            "categories": "medicine,gov,finance,notes",
        },
        "classifier.weight": {
            "dtype": "F32",
            "shape": [4, 3],
            "data_offsets": [0, len(emb_bytes)],
        },
        "classifier.bias": {
            "dtype": "F32",
            "shape": [3],
            "data_offsets": [len(emb_bytes), len(emb_bytes) + len(bias_bytes)],
        },
    }

    header_json = json.dumps(header_dict, ensure_ascii=False).encode("utf-8")
    # Выравнивание заголовка кратно 8 байтам пробелами (по спецификации safetensors)
    pad = (8 - (len(header_json) % 8)) % 8
    header_json += b" " * pad

    # Первые 8 байт: длина JSON-заголовка в uint64 little-endian ('<Q')
    header_size_bytes = struct.pack("<Q", len(header_json))

    with file_path.open("wb") as f:
        f.write(header_size_bytes)
        f.write(header_json)
        f.write(emb_bytes)
        f.write(bias_bytes)


def inspect_safetensors_header(file_path: Path) -> None:
    """Читает только заголовок .safetensors, не трогая гигабайты весов."""
    print("=== 2. Инспекция бинарного заголовка .safetensors (Zero-Copy Header) ===")
    total_size = file_path.stat().st_size
    with file_path.open("rb") as f:
        raw_len = f.read(8)
        (header_len,) = struct.unpack("<Q", raw_len)
        header_raw = f.read(header_len)
        header = json.loads(header_raw.decode("utf-8"))

    print(f"  Файл: {file_path.name} (общий размер: {total_size} байт)")
    print(f"  Первые 8 байт (uint64) -> длина JSON-заголовка: {header_len} байт")
    print(f"  Смещение начала буфера сырых тензоров: {8 + header_len} байт")
    print("  Метаданные:", header.get("__metadata__"))
    print("  Тензоры внутри файла:")
    for name, info in header.items():
        if name == "__metadata__":
            continue
        start, end = info["data_offsets"]
        print(
            f"    - {name:20s} dtype={info['dtype']} "
            f"shape={info['shape']} bytes=[{start}..{end}] ({end - start} B)"
        )


if __name__ == "__main__":
    demo_pickle_danger()
    with tempfile.TemporaryDirectory() as tmpdir:
        st_file = Path(tmpdir) / "doc_router.safetensors"
        create_minimal_safetensors(st_file)
        inspect_safetensors_header(st_file)
