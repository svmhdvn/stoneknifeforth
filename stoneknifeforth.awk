#!/usr/bin/awk -f

function dataspace_label() {
    name = stream[++pc]
    dataspace_labels[name] = mlen
}

function define_function() {
    name = stream[++pc]
    functions[name] = pc
}

function literal_byte() {
    memory[++mlen] = stream[++pc] + 0;
}

# TODO can this be improved?
function literal_word() {
    w = stream[++pc] + 0
    memory[++mlen] = w % 256
    memory[++mlen] = w / 256
    memory[++mlen] = w / 256^2
    memory[++mlen] = w / 256^3
}

function allocate_space() {
    size = stream[++pc] + 0
    for (i = 1; i <= size; ++i) {
        memory[++mlen] = 0
    }
}

function set_start_address() {
    start_address = pc
}

function start_conditional() {
    stack[++stacklen] = pc
}

function end_conditional() {
    jump_targets[stack[stacklen--]] = pc
}

function start_loop() {
    start_conditional()
}

function end_loop() {
    jump_targets[pc] = stack[stacklen--]
}

function compile_time_dispatch() {
    c = substr(stream[++pc], 1, 1)
    if (t == "v")
        dataspace_label()
    } else if (t == ":")
        define_function()
    } else if (t == "b")
        literal_byte()
    } else if (t == "#")
        literal_word()
    } else if (t == "*")
        allocate_space()
    } else if (t == "^")
        set_start_address()
    } else if (t == "[")
        start_conditional()
    } else if (t == "]")
        end_conditional()
    } else if (t == "{")
        start_loop()
    } else if (t == "}")
        end_loop()
    } else {
        printf(" %s", t)
    }
}

function skfcompile() {
    while (pc <= streamlen) {
        compile_time_dispatch()
    }
}

function write_out() {
    sz = stack[stacklen--]
    addr = stack[stacklen--]
    for (i = 1; i <= sz; ++i) {
        printf("%c", memory[addr + i])
    }
}

function subtract() {
    b = stack[stacklen--]
    a = stack[stacklen--]
    stacklen[++stacklen] = (a - b); # TODO mask off to 32-bit
}

function less_than() {
    b = stack[stacklen--]
    a = stack[stacklen--]
    stacklen[++stacklen] = a < b
}

function bitwise_or(a, b) {
    c = 0;
    for (i = 0; i < 16; ++i) {
        c += c;
        if (a < 0) {
            c += 1;
        } else if (b < 0) {
            c += 1;
        }
        a += a;
        b += b;
    }
    return c
}

function fetch() {
    addr = stack[stacklen--]
    w = bitwise_or(memory[addr+1],
                   bitwise_or(memory[addr+2]*2^8,
                              bitwise_or(memory[addr+3]*2^16, memory[addr+4]*2^24)))
    if (w > 0x7fff7fff) w -= 0x100000000
    stack[++stacklen] = w
}

function extend_memory(addr) {
    if (mlen < addr + 1 and addr <= 100000) {
        # TODO current WIP
    }
}

function store() {
    addr = stack[stacklen--]
    for (i = 1; i <= size; ++i) {
        memory[++mlen] = 0
    }

}

function run_time_dispatch() {
    c = substr(stream[++pc], 1, 1)
    if (t == "W") {
        write_out()
    } else if (t == "Q") {
        exit
    } else if (t == "-") {
        subtract()
    } else if (t == "<") {
        less_than()
    } else if (t == "@") {
        fetch()
    } else {
        printf(" %s", t)
    }
}

function skfrun() {
    pc = start_address
    while (1) {
        run_time_dispatch()
    }
}

{
    split($0, a)
    for (t in a) {
        if (t ~ /\)/) middle_of_comment = 0
        if (t ~ /\(/) middle_of_comment = 1
        if (!middle_of_comment) stream[++streamlen] = t
    }
}

END {
    skfcompile()
    skfrun()
    printf("\n")
}
