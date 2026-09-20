# store-repo — PR-S2 宿主静态仓库（教学）

QEMU user 网关下，Guest 默认仓库为 `10.0.2.2:8080`（宿主本机）。

```bash
cd ToyImage/store-repo
python3 -m http.server 8080
```

Guest（需网卡就绪，builtin TCP，非 lwIP 亦可）:

```text
ping 10.0.2.2
store repo                 # 默认 10.0.2.2:8080
store sync                 # → Store/catalog.txt
store fetch hello          # → Store/HELLO.ELF
store install hello        # → Apps/HELLO.ELF
exec Apps/HELLO.ELF
```

可选：`dbset store.repo 10.0.2.2:8080`

`catalog.txt` 的 `sha256`：`-` 跳过；若为 **8 位 hex**，按内核 **FNV-1a-32**（教学，非真 SHA-256）校验正文。
