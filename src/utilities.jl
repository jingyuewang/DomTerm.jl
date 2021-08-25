function check_domterm()
    global isDomterm

    isDomterm = true
    try
        if Sys.isunix()
            run(`domterm is-domterm`)
        else
            println("Domterm can only run in Unix or WSL")
        end
    catch err
        println("Not running in domterm\n")
        isDomterm = false
    end
end

"""add a CSS style rule to domterm

    Example ::
    ```Julia

       dt_addstyle("table {border: 1px solid}")
       dt_addstyle("table td{border-color: red}")

    ```
    The above functions set all tables in the current DomTerm session
    to have 1px-width border and red for the inner-border color.

"""
function dt_addst(rule1::String, rules...)
    args = rule1*" "*join(rules, ' ')
    r = String(read(`domterm add-style $args`))
    return nothing
end

function dt_settings(args...)
    arg = args.join(' ')
    r = run(`domterm $arg`)
    return nothing
end

function dt_reversevideo(turn_on::Bool=true)
    arg = turn_on ? "on" : "off"
    run(`domterm reverse-video $arg`)
    return nothing
end

function dt_status()
    s = read(`domterm status`, String)
    return s
end

function dt_list()
    s = read(`domterm list`, String)
    return s
end

function dt_listst()
    s = read(`domterm list-stylesheets`, String)
    return s
end

function dt_printst(i)
    s = read(`domterm print-stylesheet $i`, String)
    return s
end

using Base64: Base64EncodePipe

const img_style="display:block; margin:auto;"

function imagecat(mime::AbstractString, fn::AbstractString; attr="")
    at = img_style
    if !isempty(attr); at *= attr; end
    x = open(fn) do io
        read(io)
    end # x is Vector{UInt8}
    buf = IOBuffer()
    b64 = Base64EncodePipe(buf)
    write(b64, x)
    close(b64)
    uri = String(take!(buf))
    print("\e]72;<img style=\" $(at) \" src='data:$(mime);base64,", uri, "'/>\a")
end

svgcat(fn::AbstractString; attr="") = imagecat("image/svg+xml", fn; attr)
pngcat(fn::AbstractString; attr="") = imagecat("image/png", fn; attr)
jpegcat(fn::AbstractString; attr="") = imagecat("image/jpeg", fn; attr)
gifcat(fn::AbstractString; attr="") = imagecat("image/gif", fn; attr)

raw_htmlcat(html_content::String) = print("\e]72;"*html_content*"\a")
hput(html_content::String) = raw_htmlcat(html_content)

function htmlcat(fn::AbstractString)
    x = String(open(io -> read(io), fn))

    # remove elements not recognized by domterm
    x = replace(x, r"<\?xml.*?>"s=>"")
    x = replace(x, r"<!DOCTYPE.*?>"s=>"")
    x = replace(x, r"<!doctype.*?>"s=>"")
    x = replace(x, r"<mfenced.*?>"s=>"")
    x = replace(x, r"</mfenced>"s=>"")
    #x = replace(x, r"\n"=>"") # strip extra spaces off the output

    raw_htmlcat(x)
end

dt_clear() = println("\e[7J")

# Copied from DomTerm documentation
# "\e]721;" key ";" html-text "\a"
#
# Replace previously-inserted HTML. Looks for the latest element (in document
# order) whose class includes can-replace-children and that has a
# replace-key="key" attribute. Essentially sets the innerHTML to html-text
# (after safety-scrubbing). 

const dt_cmd = Dict(
    :reversevid => dt_reversevideo,
    :clear => dt_clear,
    :status => dt_status,
    :list => dt_list,
    :listst => dt_listst,
    :printst => dt_printst,
    :addst => dt_addst,
    :set => dt_settings,
    :jpegcat => jpegcat,
    :pngcat => pngcat,
    :svgcat => svgcat,
    :gifcat => gifcat,
    :htmlcat => htmlcat
)
macro dt(cmd, args...)
    if isempty(args)
        expr = Expr(:call, dt_cmd[cmd])
    else
        expr = Expr(:call, dt_cmd[cmd], args...)
    end

    r = eval(expr)
    r !== nothing && println(r)
    return nothing
end

# get the size in pixel of the current terminal
iolock_begin() = ccall(:jl_iolock_begin, Cvoid, ())
iolock_end() = ccall(:jl_iolock_end, Cvoid, ())

function tty_set_raw!(io::IO, isRaw::Bool)
    iolock_begin()
    ccall(:jl_tty_set_mode, Int32, (Ptr{Cvoid},Int32), io.handle::Ptr{Cvoid}, isRaw)
    iolock_end()
end

function dt_winsizex()

    h = w = -1

    tty_set_raw!(stdin, true)
    write(stdout, "\e[14t")
    out = Vector{UInt8}()
    while true
        ch = read(stdin, Char)
        push!(out, ch)
        ch == 't' && break
    end
    tty_set_raw!(stdin, false)

    vh = Vector{UInt8}()
    vw = Vector{UInt8}()

    i = findfirst([UInt8(';')], out).start
    i == nothing && error("malformed xterm report")

    i += 1
    while out[i] != UInt8(';')
        push!(vw, out[i])
        i += 1
    end
    i += 1
    while out[i] != UInt8('t')
        push!(vh, out[i])
        i += 1
    end

    w = parse(Int, String(vw), base=10)
    h = parse(Int, String(vh), base=10)
    return h, w
end

