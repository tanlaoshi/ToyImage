# _exec-lib.sh — ToyImage/Scripts 薄入口共用：找 Scripts/lib 或旁仓 OpenBox
# 用法：. "$(dirname "$0")/_exec-lib.sh" && toyos_exec_lib "$(basename "$0")" "$@"
toyos_exec_lib() {
    local Name="$1"
    shift
    local Here Root Lib Target
    # $0 仍是调用本函数的薄入口（Image/Scripts/*.sh）
    Here="$(cd "$(dirname "$0")" && pwd)"
    for Root in \
        "${TOYOS_ROOT:-}" \
        "$(cd "$Here/../.." 2>/dev/null && pwd)" \
        "$(cd "$Here/.." 2>/dev/null && pwd)"
    do
        [ -n "$Root" ] || continue
        for Lib in "$Root/Scripts/lib" "$Root/ToyKernel/OpenBox/Scripts/lib"; do
            Target="$Lib/$Name"
            if [ -f "$Target" ]; then
                exec "$Target" "$@"
            fi
        done
    done
    echo "error: missing lib/$Name（需 \$TOYOS_ROOT/Scripts/lib 或 ToyKernel/OpenBox/Scripts/lib）" >&2
    exit 1
}
