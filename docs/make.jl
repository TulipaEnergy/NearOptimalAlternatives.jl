using NearOptimalAlternatives
using Documenter

DocMeta.setdocmeta!(
  NearOptimalAlternatives,
  :DocTestSetup,
  :(using NearOptimalAlternatives);
  recursive = true,
)

makedocs(;
  modules = [NearOptimalAlternatives],
  doctest = true,
  linkcheck = true,
  authors = "Matthijs Arnoldus <m.arnoldus-1@tudelft.nl> and contributors",
  repo = "https://github.com/TulipaEnergy/NearOptimalAlternatives.jl/blob/{commit}{path}#{line}",
  sitename = "NearOptimalAlternatives.jl",
  format = Documenter.HTML(;
    prettyurls = get(ENV, "CI", "false") == "true",
    canonical = "https://TulipaEnergy.github.io/NearOptimalAlternatives.jl",
    assets = ["assets/style.css"],
  ),
  pages = [
    "Home" => "index.md",
    "Contributing" => "contributing.md",
    "Dev setup" => "developer.md",
    "Reference" => "reference.md",
  ],
)

deploydocs(; repo = "github.com/TulipaEnergy/NearOptimalAlternatives.jl", push_preview = true)
