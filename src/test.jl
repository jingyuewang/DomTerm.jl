using DomTerm
using FileIO
using Colors
using ImageShow
using ImageTransformations
using Base64: Base64EncodePipe

import Base: show

#### UNIT TEST
#

#function parser_test()
#    #l = raw"(a + b) * c"
#    #l = raw"a_2 + 3.14"
#    #l = raw"a_{2+i} + b"
#    #l = raw"α + ∑_{i=0}^n 2^i"
#    #l = raw"a \over b"
#    #l = raw"{x^2+2x+1}\over{x+1} + x^3"
#    #l = raw"1+(2*3) + 1.333 \alpha a"
#    #l = raw"\frac{-b \pm \sqrt{b^2-4ac}}{2a}"
#    #l = raw"\frac{2}{a+1} \times 2 b"
#    #l = raw"\pmatrix{a & 1 \\ 2 & 2}"
#    #l = raw"\begin{bmatrix} a_1 & b^2 \\ 2.25 & \sin x \end{bmatrix}"
#    #l = raw"\pmatrix{a_1 & b^2 \\ 2.25 & \sin x}"
#    #l = raw"$$\pmatrix{a_{1,1} & a_{1,2} \\ a_{2,1} & a_{2,2} }$$"
#    #l = scan_tex(raw"\begin{align} a^2 = b^2 + c^2 \end{align}")
#    #l = raw"∫_2^3 f(x) \,dx"
#    #l = raw"\sqrt{\sqrt{\left( x^3 \right) + v}}"
#    #l = raw"\frac{3}{\frac{1}{2}x^2}"
#    #l = raw"\lim_{x \to \infty} f(x)"
#    #l = raw"d = \mathfrak{ABC}"
#    #l = raw"$$\mathfrak{E} = mc^2$$"
#    #l = raw"x = \mathbf{A} + \mathbb{B} + \mathcal{C} + \mathfrak{D}"
#    #l = raw"$$\int_0^\infty e^{-x}\,dx, \qquad y = 2.$$"
#
#    #top, tks = scan_tex(l)
#    #ts = TokenStream(l)
#    #nodes = parse!(ts)
#
#    # print token stream
#    #print_token_stream(ts)
#
#    # print ast
#    #print_expr(nodes, 0)
#    #println()
#    
#    # print raw mml
#    #println(exlist_to_mml(nodes))
#
#    # pretty-print mml
#    #pretty_print_mml(exlist_to_mml(nodes))
#
#    # show rendered formula in DomTerm
#    #dshow(l)
#    #
#    #l = LATEX(raw"\alpha = a^2")
#    #display(MIME("text/html"), "<p style=\"text-align:center; font-family:Flexi IBM VGA True; font-size:150%\">Hello world</p>")
#    #display(MIME("text/mathml+xml"), l)
#    #a = RGB{N0f8}(0.8, 0.1, 0.1)
#    #display("image/svg+xml", a)
#    #println(a)
#
#    #display("image/png", rand(RGB{Colors.N0f8}, 5, 5))
#    #cam = testimage("cameraman")
#    #display("image/png", cam)
#    #display(rand(RGB{Colors.N0f8}, 5, 5))
#    
#    im = load("/home/jwang/doc/pic/helloworld.jpeg")
#    display("image/jpeg", im)
#end

#parser_test()
#lexer_test()
#
#println(length(Base.Multimedia.displays))
#t = LATEX(raw"$$\alpha=3$$")
#display(MIME("text/mathml+xml"), t)
#println()

#is_domterm()
#dt_status()
#dt_list()
#dt_listst()
h, w = dt_winsize()
println(h, " --- ", w)
img_dir = "/home/jwang/doc/pic/"
flist = readdir("/home/jwang/doc/pic/")

IMAGE_FILETYPES = [:GIF, :JPEG, :PNG, :PGMBinary]
function is_image(filename)
    q = query(filename)
    for mtype in IMAGE_FILETYPES
        q isa File{DataFormat{mtype}, String} && return true
    end
    return false
end

imglist = filter(is_image, flist)

DTInlineIOContext(io, KVs::Pair...) = IOContext(
    io,
    :limit=>true, :color=>true, :domterm=>true,
    KVs...
)


function make_div(st, content)
    return "<div style=\"$st\">"*content*"</div>"
end

function make_img(st, content::String)
    return "<img style=\"$st\" src='data:image/png;base64,"*content*"' />"
end

function make_polimg(style, img::AbstractMatrix{<:Colorant}; ratio=0.5, maxlen=10^6)
    buf = IOBuffer()
    b64 = Base64EncodePipe(buf)
    if applicable(length, img) && length(img) > maxlen
        img = imresize(img; ratio)
    end
    show(DTInlineIOContext(b64), MIME("image/png"), img)
    content = String(take!(buf))
    close(b64)

    return make_img(style, content)
end

function make_polaroid(img::AbstractMatrix{<:Colorant}, title::String)
    style = ""
    style *= "width: 256px;"
    style *= "height: 256px;"
    style *= "background-color: white;"
    style *= "box-sizing: border-box;"
    style *= "float: left;"
    style *= "margin: 30px 20px;"
    style *= "box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2), 0 6px 20px 0 rgba(0, 0, 0, 0.19);"
    style *= "position: relative;"

    im_style = ""
    im_style *= "max-width: 90%;"
    im_style *= "width: auto;"
    im_style *= "max-height: 70%;"
    im_style *= "height: auto;"
    im_style *= "display: block;"
    im_style *= "margin: 0.5em auto auto;"

    tt_style = ""
    tt_style *= "margin-left: 10%;"
    tt_style *= "margin-right: 10%;"
    tt_style *= "position: absolute;"
    tt_style *= "bottom: 10px;"

    return make_div(style, make_polimg(im_style, img)*make_div(tt_style, title))
end

function make_newline()
    style = "clear:left; "
    return make_div(style, "")
end

#im1 = load("/home/jwang/doc/pic/helloworld.png")
#im2 = load("/home/jwang/doc/pic/Teleprinter.gif")
#im3 = load("/home/jwang/doc/pic/Blue Origin logo.jpeg")
#print("\e]72;")
for fn in imglist
    im = load(img_dir*fn)
    if length(size(im)) <= 2
        #println(typeof(im), " --- ", fn, " : ", length(size(im)))
        print("\e]72;")
        print(make_polaroid(im, fn))
        print("\a")
    end
end
print("\e]72;")
print(make_newline())
print("\a")
#print("\a")

