module DomTerm

include("display.jl")
include("utilities.jl")

isDomterm = false

export
    # status info
    dt_status, dt_list,
    # stylesheets
    dt_listst, dt_printst, dt_addst,
    # screen setting
    dt_reversevideo, dt_clear, dt_winsizex,
    # general setting
    dt_settings,
    # file display
    hput, htmlcat, svgcat, jpegcat, pngcat, gifcat,
    # helper functions
    displayinline,
    # macros
    @dt

function __init__()
    check_domterm()
    pushdisplay(DomTermInline())
end # __init__

end # DomTerm 
