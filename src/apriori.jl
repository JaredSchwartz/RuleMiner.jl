# apriori.jl
# Apriori rule mining in Julia
#
# Copyright (c) 2024 Jared Schwartz
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

export apriori

"""
    apriori(txns::Transactions, minsup::Real, maxlen::Int; minconf::Union{Real,Nothing}=nothing)


Identify association rules in a transactional dataset `txns`, with minimum support, `minsup`, 
and maximum rule length, `maxlen`.

Optionally, pass a minimum confidence level with the `minconf` kwarg
"""
function apriori(txns::Transactions, minsup::Real, maxlen::Int; minconf::Union{Real,Nothing}=nothing)
    
    Overall_Length = size(txns.matrix)[1]
    Overall_Number = vec(sum(txns.matrix, dims=1))
    Overall_Support = Overall_Number / Overall_Length

    function Siblings(items::Vector{Int},value::Int)
        return filter(x -> x != value, items)
    end

    function GetNames(indexes)
        return getindex.(Ref(txns.colkeys), indexes)
    end

    items = findall(x -> x > minsup, Overall_Support)

    rules = DataFrame(
        LHS = [missing for item in items],
        RHS = GetNames(items),
        Support = Overall_Support[items],
        Coverage = [1.0 for i in items],
        Cov_y = [1.0 for i in items],
        N = [Overall_Number[item] for item in items],
        Length = [1 for i in items],
        Filters = [[i] for i in items],
        PotentialRHS = map(x -> Siblings(items,x),items),
    )
    if maxlen > 1
        for CurrentLength in range(1,maxlen-1)
            
            CurrentLevel = filter(:Length => x -> (x == CurrentLength), rules)
            CurrentLevel = filter(:PotentialRHS => x -> length(x) > 0, rules)
            if nrow(CurrentLevel) == 0
                continue
            end
            
            for i in range(1,nrow(CurrentLevel))
                Spec = CurrentLevel[i,:]
                
                subtrans = txns.matrix[vec(any(txns.matrix[:, Spec[:Filters]] .!= 0, dims=2)), :]

                Num_X_Y = vec(sum(subtrans, dims=1))
                Support_X_Y = Num_X_Y / Overall_Length
                
                items = findall(x -> x > minsup, Support_X_Y)
                items = filter(x -> (x in Spec[:PotentialRHS]), items)

                NewRules = DataFrame(
                    LHS = [GetNames(Spec[:Filters]) for i in items],
                    RHS = GetNames(items),
                    Support = Supports = Support_X_Y[items],
                    Coverage = [Spec[:Support] for item in items],
                    Cov_y = [Overall_Support[item] for item in items],
                    N = [Num_X_Y[item] for item in items],
                    Length = CurrentLength+1,
                    Filters = [vcat(Spec[:Filters],Vector([item])) for item in items],
                    PotentialRHS = map(x -> Siblings(items,x),items)
                )

                append!(rules,NewRules,promote=true)
            end
        end
    end

    transform!(rules,[:Support,:Coverage] => ((x,y) -> x./y) => :Confidence)
    transform!(rules,[:Confidence,:Cov_y] => ((x,y) -> x./y) => :Lift)
    select!(rules,[:LHS,:RHS,:Support,:Confidence,:Coverage,:Lift,:N])
    
    if !isnothing(minconf)
        filter!(:Confidence => (x -> x > minconf), rules)
    end

    return rules
end