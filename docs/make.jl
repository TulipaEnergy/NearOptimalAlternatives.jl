using NearOptimalAlternatives
using Documenter

DocMeta.setdocmeta!(
    NearOptimalAlternatives,
    :DocTestSetup,
    :(using NearOptimalAlternatives);
    recursive = true,
)

const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [NearOptimalAlternatives],
    authors = "",
    sitename = "NearOptimalAlternatives.jl",
    format = Documenter.HTML(;
        canonical = "https://TulipaEnergy.github.io/NearOptimalAlternatives.jl",
    ),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/TulipaEnergy/NearOptimalAlternatives.jl")
