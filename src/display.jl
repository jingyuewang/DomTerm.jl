#                       The display module for DomTerm.jl
#
# lend idea and code from the `IJulia.jl` package
#
#       J.Wang, 2021

import Base: show, display, redisplay

using Base64: Base64EncodePipe

struct DomTermInline <: AbstractDisplay end

# supported MIME types for DomTerm inline display, in descending order
# of preference (descending "richness")
const DT_mime = [
    #"application/vnd.dataresource+json",
    #["application/vnd.vegalite.v$n+json" for n in 4:-1:2]...,
    #["application/vnd.vega.v$n+json" for n in 5:-1:3]...,
    #"application/vnd.plotly.v1+json",
    "text/html",
    "text/mathml+xml",
    "text/latex",
    "image/svg+xml",
    "image/png",
    "image/jpeg",
    #"application/javascript",
    #"text/markdown",
    "text/plain"
]

DTInlineIOContext(io, KVs::Pair...) = IOContext(
    io,
    :limit=>true, :color=>true, :domterm=>true,
    KVs...
)

# need special handling for showing a string as a textmime
# type, since in that case the string is assumed to be
# raw data unless it is text/plain (JW: handled by the show() function)
# JW: For any type signature that you want to implement in show()
# let the `israwtext()` function with the same signature return false
israwtext(::MIME"text/plain", x::AbstractString) = false
israwtext(::MIME"text/html", x::AbstractString) = false
israwtext(::MIME"text/mathml+xml", x::AbstractString) = false
israwtext(::MIME, x::AbstractString) = true
israwtext(::MIME, x) = false

# convert x to a string of type mime, making sure to use an
# IOContext that tells the underlying show function to limit output
function limitstringmime(mime::MIME, x)
    buf = IOBuffer()
    if istextmime(mime)
        if israwtext(mime, x)
            return String(x)
        else
            # If the raw data `x` is really large and `x` is shown as
            # "image/svg+xml", The `show()` function defined in `ImageShow()`
            # emits tons of SVG commands, sometimes hanges `DomTerm`. We
            # temporarily disable showing large inline SVG images. Use an
            # external viewer instead or show it as PNG.
            if applicable(length, x) && length(x) > 10^5
                print("data too large to show inline. If this is an image, try show it as PNG, or use an external viewer.")
                return ""
            else
                show(DTInlineIOContext(buf), mime, x)
            end
        end
    else
        b64 = Base64EncodePipe(buf)
        if isa(x, Vector{UInt8})
            write(b64, x) # x assumed to be raw binary data
        else
            # if the input array `x` is really large (length > 4M, which means
            # even down-sampled array is still more than 1M long), The `show()`
            # function defined in `ImageShow` emits tons of base64 bytes and
            # hanges `DomTerm`. We temporarily disable showing large inline
            # images. I'm not sure the following 1M bar is proper or not...
            if applicable(length, x) && length(x) > 1*10^6
                print("data too large to show inline. Please use an external viewer.")
                close(b64)
                return ""
            else
                show(DTInlineIOContext(b64), mime, x)
            end
        end
        close(b64)
    end
    return String(take!(buf))
end

# deal with annoying application/x-latex == text/latex synonyms
display(d::DomTermInline, m::MIME"application/x-latex", x) =
    display(d, MIME("text/latex"), limitstringmime(m, x))

# deal with annoying text/javascript == application/javascript synonyms
display(d::DomTermInline, m::MIME"text/javascript", x) =
    display(d, MIME("application/javascript"), limitstringmime(m, x))

function display(d::DomTermInline, M::MIME, x)
    sx = limitstringmime(M, x)
    d = Dict(string(M) => sx)
    if istextmime(M)
        d["text/plain"] = sx # directly show text data, e.g. text/csv
    end

    # JW: I should print it more properly...
    print(sx)
end
displayable(d::DomTermInline, M::MIME) = istextmime(M)

# define `display` function for all supported MIMEs
for mime in DT_mime
    @eval begin
        function display(d::DomTermInline, ::MIME{Symbol($mime)}, x)
            print("\e]72;") # wire byte code for inserting a HTML fragment
            publish_mime_string(MIME($mime), limitstringmime(MIME($mime), x))
            print("\a") # HTML fragment end
        end
        displayable(d::DomTermInline, ::MIME{Symbol($mime)}) = true
    end
end
# register single-argument function `display(x)` for html-type objects
display(d::DomTermInline, x::HTML) = display(d, MIME("text/html"), x)

function publish_mime_string(::MIME"image/svg+xml", x::String)
    # Remove svg file headers. Package `Colors` generates these headers in
    # running `display(MIME("image/svg+xml"), RGB{N0f8}(...))`. DomTerm
    # can not understand them.
    x = replace(x, r"<\?xml.*?>"s=>"")
    x = replace(x, r"<!DOCTYPE.*?>"s=>"")
    x = replace(x, r"\n"=>"") # strip extra spaces off the output
    print(x)
end

function publish_mime_string(::MIME"image/png", x::String)
    if !isempty(x)
        # if the input data used too much memory, x could be empty
        print("<img src='data:image/png;base64,")
        print(x)
        print("' />")
    end
end

publish_mime_string(::MIME, s::String) =  print(s)


