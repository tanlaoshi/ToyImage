#!/usr/bin/expect -f
#
# test-enosys.sh — 开课前：未知 syscall → -ENOSYS（Guest ENOSYS.ELF）
# 在 ToyImage 根跑：./Scripts/test-enosys.sh（需 expect；ELF 由 ToyKernel ./build.sh 同步）
#
set LOG "/tmp/toyos-test-enosys.log"
set BOOT_TO 90
set PROMPT_TO 10
set CMD_TO 20
set HALT_TO 10

proc cleanup { } {
    catch { exec pkill -9 -f "qemu-system-x86_64" }
}

proc fail_dump { } {
    global LOG
    send_user "=== FAIL, log tail ===\n"
    catch { exec tail -80 $LOG } tail
    send_user "$tail\n"
    cleanup
    exit 1
}

cleanup
log_file -noappend $LOG

set image_root [pwd]
if {[file exists [file join $image_root run-split.sh]]} {
    # cwd = ToyImage/Scripts（test-all 入口）
    set image_root [file dirname $image_root]
} elseif {![file exists [file join $image_root Scripts run-split.sh]]} {
    set image_root [file normalize [file join [pwd] .. ToyImage]]
}
if {![file exists [file join $image_root Scripts run-split.sh]]} {
    send_user "error: ToyImage not found (run from ToyImage or ToyImage/Scripts)\n"
    exit 2
}

send_user "spawn run-split.sh --kill-qemu --headless --smp=1 (cwd=$image_root)\n"
spawn sh -c "cd $image_root && ./Scripts/run-split.sh --kill-qemu --headless --smp=1"

set timeout $BOOT_TO
expect {
    -re "ToyOS ready|ToyOS 就绪" {
        send_user "ok: boot\n"
    }
    timeout {
        send_user "timeout waiting ToyOS ready\n"
        fail_dump
    }
}

set timeout $PROMPT_TO
send "\r"
expect {
    -re "toyos>" {
        send_user "ok: prompt\n"
    }
    timeout {
        send_user "timeout waiting toyos>\n"
        fail_dump
    }
}

set timeout $CMD_TO
send "exec ENOSYS.ELF\r"
expect {
    -re "toyos>" {
        if {[regexp -- {enosys: ok} $expect_out(buffer)]} {
            send_user "ok: enosys demo\n"
        } else {
            send_user "assert fail: expected 'enosys: ok'\n"
            fail_dump
        }
    }
    timeout {
        send_user "timeout after exec ENOSYS.ELF\n"
        fail_dump
    }
}

send "halt\r"
set timeout $HALT_TO
expect {
    eof { send_user "ok: qemu exited\n" }
    timeout {
        send_user "halt: killing qemu\n"
        cleanup
    }
}

send_user "=== PASS ===\n"
exit 0
