```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: RuleMiner.jl
  text: Fast Data Mining in Julia
  tagline: RuleMiner is a package for association rule and frequent itemset mining inspired by the <u><a class="VPLink link vp-external-link-icon" href= https://github.com/mhahsler/arules>arules</a></u> R package and <u><a class="VPLink link vp-external-link-icon" href= https://www.philippe-fournier-viger.com/spmf/>SPMF</a></u> Java library.
  actions:
    - theme: brand
      text: Get Started
      link: /tutorials/getting_started
    - theme: alt
      text: API Reference
      link: /api_reference
    - theme: alt
      text: View on GitHub
      link: https://github.com/JaredSchwartz/RuleMiner.jl
  image:
    src: /assets/logo.svg
    alt: RuleMiner.jl logo

features:
  - icon: 🚀
    title: Fast & Multithreaded
    details: Supports Julia's native multithreading capabilities for improved performance

  - icon: 🤝
    title: Friendly input and output formats
    details: Directly integrates with Dataframes.jl for input and output

  - icon: ↔️
    title: Flexible API
    details: Designed for multiple use cases, including both relative and absolute support calculation.
---
```