"""Вырезает из базовой модели Quaternius (Superhero_*_FullBody.gltf) только голову и шею.

Одежда из пака Modular Character Outfits рассчитана на «голову без тела»,
иначе тело просвечивает сквозь одежду. Треугольник остаётся, если все его вершины
в основном привязаны к костям головы/шеи.

Использование: python3 tools/extract_head.py <FullBody.gltf> <out.gltf>
"""

import json
import shutil
import struct
import sys
from pathlib import Path

HEAD_BONES = {"Head", "neck_01"}
THRESHOLD = 0.5
FMT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
NORM = {5121: 255.0, 5123: 65535.0}


def read_accessor(gltf: dict, data: bytes, idx: int) -> list[tuple]:
    acc = gltf["accessors"][idx]
    view = gltf["bufferViews"][acc["bufferView"]]
    ctype, n = acc["componentType"], NCOMP[acc["type"]]
    size = struct.calcsize("<" + FMT[ctype])
    stride = view.get("byteStride", size * n)
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return [struct.unpack_from("<" + FMT[ctype] * n, data, base + i * stride) for i in range(acc["count"])]


def main(src: Path, dst: Path) -> None:
    gltf = json.loads(src.read_text())
    bin_src = src.parent / gltf["buffers"][0]["uri"]
    data = bytearray(bin_src.read_bytes())
    joint_names = [gltf["nodes"][i]["name"] for i in gltf["skins"][0]["joints"]]
    head_ids = {i for i, name in enumerate(joint_names) if name in HEAD_BONES}

    # Самый крупный меш — тело; лицо, глаза и брови оставляем как есть.
    body = max(gltf["meshes"], key=lambda m: gltf["accessors"][m["primitives"][0]["indices"]]["count"])
    for prim in body["primitives"]:
        attrs = prim["attributes"]
        joints = read_accessor(gltf, data, attrs["JOINTS_0"])
        w_acc = gltf["accessors"][attrs["WEIGHTS_0"]]
        weights = read_accessor(gltf, data, attrs["WEIGHTS_0"])
        scale = NORM.get(w_acc["componentType"], 1.0)
        head_share = [
            sum(w / scale for j, w in zip(js, ws) if j in head_ids) for js, ws in zip(joints, weights)
        ]
        flat = [i[0] for i in read_accessor(gltf, data, prim["indices"])]
        kept = [
            flat[t : t + 3]
            for t in range(0, len(flat), 3)
            if all(head_share[v] >= THRESHOLD for v in flat[t : t + 3])
        ]
        new_indices = [v for tri in kept for v in tri]
        print(f"{body['name']}: {len(flat) // 3} -> {len(kept)} треугольников")

        while len(data) % 4:
            data.append(0)
        offset = len(data)
        data += struct.pack(f"<{len(new_indices)}I", *new_indices)
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(new_indices) * 4, "target": 34963})
        gltf["accessors"].append({"bufferView": len(gltf["bufferViews"]) - 1, "componentType": 5125, "count": len(new_indices), "type": "SCALAR"})
        prim["indices"] = len(gltf["accessors"]) - 1

    body["name"] = "Head"
    # Текстуры лежат рядом с исходником — копируем упомянутые.
    # В паке часть ссылок битая: «X_png.png» на диске называется «X.png».
    for img in gltf.get("images", []):
        uri = img.get("uri")
        if not uri:
            continue
        if not (src.parent / uri).exists():
            uri = img["uri"] = uri.replace("_png.png", ".png")
        if not (dst.parent / uri).exists():
            shutil.copy(src.parent / uri, dst.parent / uri)

    dst_bin = dst.with_suffix(".bin")
    gltf["buffers"][0] = {"uri": dst_bin.name, "byteLength": len(data)}
    dst.write_text(json.dumps(gltf))
    dst_bin.write_bytes(data)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
