# Abbreviation to help keep code short!
const AMSA = AbstractMultiScaleArray

Base.map!(f::F, m::AMSA, A0::AbstractArray, As::AbstractArray...) where {F} =
        broadcast!(f, m, A0, As...)
Base.map!(f::F, m::AMSA, A0, As...) where {F} =
        broadcast!(f, m, A0, As...)

Base.BroadcastStyle(::Type{<:AMSA}) = Broadcast.ArrayStyle{AMSA}()
Base.BroadcastStyle(::Type{<:AbstractMultiScaleArrayLeaf}) = Broadcast.ArrayStyle{AbstractMultiScaleArrayLeaf}()

@inline function Base.copy(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{AMSA}})
    first_amsa = find_amsa(bc)
    out = similar(first_amsa)
    copyto!(out,bc)
    out
end

@inline function Base.copy(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{AbstractMultiScaleArrayLeaf}})
    first_amsa = find_amsa(bc)
    out = similar(first_amsa)
    copyto!(out,bc)
    out
end

@inline function Base.copyto!(dest::AMSA, bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{AMSA}})
    if !any_non_amsa(bc)
        N = length(dest.nodes)
        for i in 1:N
            copyto!(dest.nodes[i], unpack(bc, i))
        end
        copyto!(dest.values,unpack(bc, nothing))
    else
        copyto!(dest,convert(Base.Broadcast.Broadcasted{Broadcast.DefaultArrayStyle{length(axes(bc))}}, bc))
    end
    dest
end

@inline function Base.copyto!(dest::AbstractMultiScaleArrayLeaf, bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{AbstractMultiScaleArrayLeaf}})
    if !any_non_amsa(bc)
        copyto!(dest.values,unpack(bc,nothing))
    else
        copyto!(dest,convert(Base.Broadcast.Broadcasted{Broadcast.DefaultArrayStyle{length(axes(bc))}}, bc))
    end
    dest
end

# drop axes because it is easier to recompute
@inline unpack(bc::Broadcast.Broadcasted, i) = Broadcast.Broadcasted(bc.f, unpack_args(i, bc.args))
unpack(x,::Any) = x
unpack(x::AMSA, i) = x.nodes[i]
unpack(x::AMSA, ::Nothing) = x.values

@inline unpack_args(i, args::Tuple) = (unpack(args[1], i), unpack_args(i, Base.tail(args))...)
unpack_args(i, args::Tuple{Any}) = (unpack(args[1], i),)
unpack_args(::Any, args::Tuple{}) = ()

nnodes(A) = 0
nnodes(A::AMSA) = length(A.nodes)
nnodes(bc::Broadcast.Broadcasted) = _nnodes(bc.args)
nnodes(A, Bs...) = common_number(nnodes(A), _nnodes(Bs))

@inline _nnodes(args::Tuple) = common_number(nnodes(args[1]), _nnodes(Base.tail(args)))
_nnodes(args::Tuple{Any}) = nnodes(args[1])
_nnodes(args::Tuple{}) = 0

"`A = find_amsa(As)` returns the first AMSA among the arguments."
find_amsa(bc::Base.Broadcast.Broadcasted) = find_amsa(bc.args)
find_amsa(args::Tuple) = find_amsa(find_amsa(args[1]), Base.tail(args))
find_amsa(x) = x
find_amsa(a::AMSA, rest) = a
find_amsa(::Any, rest) = find_amsa(rest)

any_non_amsa(bc::Base.Broadcast.Broadcasted) = any_non_amsa(bc.args)
any_non_amsa(args::Tuple) = any_non_amsa(any_non_amsa(args[1]), Base.tail(args))
any_non_amsa(x::AMSA) = false
any_non_amsa(x::Number) = false
any_non_amsa(x::Any) = true
any_non_amsa(x::AbstractArray) = true
any_non_amsa(x::Bool, rest) = isempty(rest) ? x : x || any_non_amsa(rest)

## utils
common_number(a, b) =
    a == 0 ? b :
    (b == 0 ? a :
     (a == b ? a :
      throw(DimensionMismatch("number of nodes must be equal"))))
