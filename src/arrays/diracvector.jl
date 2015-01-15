import Base: getindex,
    setindex!,
    copy,
    size,
    in,
    summary,
    +, .+,
    *, .*,
    -, .-,
    /, ./,
    ^, .^,
    Ac_mul_B,
    exp,
    sum,
    ctranspose

###############
# DiracVector #
###############
    checksize(::Type{Ket}, qa) = size(qa, 2) == 1 
    checksize(::Type{Bra}, qa) = size(qa, 1) == 1 

    type DiracVector{D, 
                     S<:AbstractStructure, 
                     T, 
                     B<:AbstractLabelBasis, 
                     A} <: DiracArray{B,ScaledState{D,S,T},1}
        quarr::QuVector{B,T,A}
        function DiracVector{L<:AbstractLabelBasis{S}}(quarr::QuVector{L,T,A})
            if checksize(D, quarr)
                new(quarr)
            else 
                error("Coefficient array does not conform to input bases")
            end
        end
    end

    function DiracVector{L<:AbstractLabelBasis,T,A}(quarr::QuVector{L,T,A}, D::DataType=Ket)
        return DiracVector{D,structure(L),T,L,A}(quarr)
    end

    function DiracVector{T,S<:AbstractStructure}(
                        coeffs::AbstractArray{T}, 
                        basis::AbstractLabelBasis{S}, 
                        D::DataType=Ket)
        return DiracVector(QuArray(coeffs, basis), D)    
    end

    DiracVector(coeffs::AbstractArray) = DiracVector(coeffs, FockBasis(length(coeffs)-1))

    DiracVector{K<:AbstractKet}(arr::AbstractArray{K}) = sum(arr)
    DiracVector{B<:AbstractBra}(arr::AbstractArray{B}) = sum(arr)

    typealias KetVector{S<:AbstractStructure, T, B<:AbstractLabelBasis} DiracVector{Ket, S, T, B}
    typealias BraVector{S<:AbstractStructure, T, B<:AbstractLabelBasis} DiracVector{Bra, S, T, B}

    ######################
    # Property Functions #
    ######################
    size(dv::DiracVector, i...) = size(dv.quarr, i...)
    bases(dv::DiracVector) = bases(dv.quarr)
    basis(dv::DiracVector) = first(bases(dv))
    coeffs(dv::DiracVector) = coeffs(dv.quarr)
    dualtype{D}(::DiracVector{D}) = D
    structure{D,S<:AbstractStructure}(::DiracVector{D,S}) = S

    copy{D}(dv::DiracVector{D}) = DiracVector(copy(coeffs(dv)), copy(basis(dv)), D)

    ###################
    # Basis Functions #
    ###################
    in{D,S<:AbstractStructure}(s::AbstractState{D,S}, dv::DiracVector{D,S}) = in(label(s), basis(dv))
    in(s::StateLabel, dv::DiracVector) = in(s, basis(dv))
    getpos{D,S<:AbstractStructure}(dv::DiracVector{D,S}, s::AbstractState{D,S}) = getpos(basis(dv), label(s))
    getpos{D,S<:AbstractStructure}(dv::DiracVector{D,S}, s) = getpos(basis(dv), s) 

    getlabel(dv::DiracVector, i) = basis(dv)[i]
    getstate{D,S<:AbstractStructure}(dv::DiracVector{D,S}, i) = DiracState{D,S}(getlabel(dv,i))
    samelabels(a::DiracVector, b::DiracVector) = samelabels(basis(a), basis(b))

    #########################
    # Coefficient Functions #
    #########################
    in(c, dv::DiracVector) = in(c, coeffs(dv))
    getcoeff{D,S<:AbstractStructure}(dv::DiracVector{D,S}, s::AbstractState{D,S}) = coeffs(dv)[getpos(dv, label(s))]
    getcoeff(dv::DiracVector, s::StateLabel) = coeffs(dv)[getpos(dv, s)]
    getcoeff(dv::DiracVector, s::Tuple) = coeffs(dv)[getpos(dv, s)]
    getcoeff(dv::DiracVector, i) = coeffs(dv)[i]

    ######################
    # getindex/setindex! #
    ######################
    getindex(dv::DiracVector, arr::AbstractArray) = DiracVector([dv[i] for i in arr])
    getindex(dv::DiracVector, i::Real) = getcoeff(dv, i) * getstate(dv, i)
    getindex(dv::DiracVector, i) = getcoeff(dv, i) * getstate(dv, i)
    getindex(dv::DiracVector, s::AbstractState) = getcoeff(dv, s) * s
    getindex(dv::DiracVector, label::StateLabel) = getcoeff(dv, label) * s
    getindex(dv::DiracVector, label::Tuple) = getcoeff(dv, label) * s
    getindex(dv::KetVector, i, j) = j==1 ? dv[i] : throw(BoundsError())
    getindex(dv::BraVector, i, j) = i==1 ? dv[j] : throw(BoundsError())

    generic_setind!(dv, c, i) = (setindex!(coeffs(dv), c, i); return dv)
    setindex!(dv::DiracVector, c, s::AbstractState) = generic_setind!(dv, c, getpos(dv, s))
    setindex!(dv::DiracVector, c, i::Real) = generic_setind!(dv, c, i)
    setindex!(dv::DiracVector, c, i) = generic_setind!(dv, c, i)
    setindex!(v::KetVector, c, i, j) = j==1 ? generic_setind!(v, c, i) : throw(BoundsError())
    setindex!(v::BraVector, c, i, j) = i==1 ? generic_setind!(v, c, j) : throw(BoundsError())

    getas{D,S<:AbstractStructure}(dv::DiracVector{D,S}, i, T=D) =  ScaledState(getcoeff(dv, i), DiracState{T,S}(getlabel(dv,i)))

    #####################
    # Joining Functions #
    #####################
    function addstate!(dv, state)
        dv[state] = getcoeff(dv, state) + coeff(state)
        return dv
    end

    function appendvec!(a, b)
        for i=1:length(b)
            a = a + b[i]
        end
        return a
    end

    function appendstate(dv::KetVector, state)
        return DiracVector(vcat(coeffs(dv), coeff(state)), append(basis(dv), label(state)), Ket)
    end

    function appendstate(dv::BraVector, state)
        return DiracVector(hcat(coeffs(dv), coeff(state)), append(basis(dv), label(state)), Bra)
    end

    ######################
    # Printing Functions #
    ######################
    summary{S<:AbstractStructure,T,B}(dv::KetVector{S,T,B}) = "KetVector in $B with $(length(dv)) $T entries"
    summary{S<:AbstractStructure,T,B}(dv::BraVector{S,T,B}) = "BraVector in $B with $(length(dv)) $T entries"

##########################
# Mathematical Functions #
##########################

    ############
    # Addition #
    ############
    function sum{K<:AbstractKet}(arr::AbstractArray{K})
        return DiracVector(makecoeffarr(arr), LabelBasis(arr), Ket)
    end

    function sum{B<:AbstractBra}(arr::AbstractArray{B})
        return DiracVector(makecoeffarr(arr), LabelBasis(arr), Bra)
    end

    function +{S<:AbstractStructure}(a::AbstractKet{S}, b::AbstractKet{S}) 
        if state(a) == state(b) 
            return DiracVector([coeff(a)+coeff(b)], LabelBasis(b), Ket) 
        else 
            return DiracVector(vcat(coeff(a), coeff(b)), LabelBasis(label(a), label(b)), Ket)
        end
    end

    function +{S<:AbstractStructure}(a::AbstractBra{S}, b::AbstractBra{S}) 
        if state(a) == state(b) 
            return DiracVector([coeff(a)+coeff(b)], LabelBasis(b), Bra) 
        else 
            return DiracVector(hcat(coeff(a), coeff(b)), LabelBasis(label(a), label(b)), Bra)
        end
    end

    function +{D,S<:AbstractStructure}(dv::DiracVector{D,S}, s::AbstractState{D,S})
        if s in dv
            return addstate!(copy(dv), s)
        else
            return appendstate(dv, s)
        end
    end

    +{D,S<:AbstractStructure}(s::AbstractState{D,S}, dv::DiracVector{D,S}) = +(dv, s)

    function +{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S})
        if samelabels(a, b)
            return DiracVector(coeffs(a)+coeffs(b), basis(a), D)
        else
            return appendvec!(copy(a), b)
        end
    end

    -(dv::DiracVector) = DiracVector(-coeffs(dv), basis(dv))
    -{D,S<:AbstractStructure}(a::AbstractState{D,S}, b::AbstractState{D,S}) = a + (-b)
    -{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::AbstractState{D,S}) = a + (-b)
    -{D,S<:AbstractStructure}(a::AbstractState{D,S}, b::DiracVector{D,S}) = a + (-b)
    -{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S}) = a + (-b)

    .+{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S}) = a + b
    .-{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S}) = a - b

    ##################
    # Multiplication #
    ##################
    function inner(b::BraVector, k::KetVector)
        result = 0
        for i=1:length(b)
            for j=1:length(k)
                result = inner(b[i],k[k]) + result       
            end
        end
        return result
    end

    *(b::BraVector, k::KetVector) = inner(a,b)

    tensor{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S}) = DiracVector(kron(coeffs(a),coeffs(b)), tensor(basis(a),basis(b)), D)
    tensor{D,S<:AbstractStructure}(a::AbstractState{D,S}, b::DiracVector{D,S}) = DiracVector(kron(coeff(a),coeffs(b)), tensor(label(a),basis(b)), D)
    tensor{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::AbstractState{D,S}) = DiracVector(kron(coeffs(a),coeff(b)), tensor(basis(a),label(b)), D)
    *{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S}) = tensor(a,b)
    *{D,S<:AbstractStructure}(a::AbstractState{D,S}, b::DiracVector{D,S}) = tensor(a,b)
    *{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::AbstractState{D,S}) = tensor(a,b)

    .*{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S}) = DiracVector(coeffs(a).*coeffs(b), hcat(basis(a),basis(b)), D)
    
    .*{D,S<:AbstractStructure}(a::AbstractState{D,S}, b::DiracVector{D,S}) = a*b
    .*{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::AbstractState{D,S}) = a*b

    function .^{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S})
        if samelabels(a, b)
            return DiracVector(coeffs(a).^coeffs(b), basis(a), D)
        else
            error("BasisMismatch")
        end
    end

    function ./{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S})
        if samelabels(a, b)
            return DiracVector(coeffs(a)./coeffs(b), basis(a), D)
        else
            error("BasisMismatch")
        end
    end

    #####################
    # Special Functions #
    #####################
    log(dv::DiracVector, i) = DiracVector(log(coeffs(dv), i), basis(dv), dualtype(dv))
    log(dv::DiracVector) = DiracVector(log(coeffs(dv)), basis(dv), dualtype(dv))
    exp(dv::DiracVector) = DiracVector(exp(coeffs(dv)), basis(dv), dualtype(dv))

    ctranspose(dv::DiracVector) = DiracVector(coeffs(dv)', basis(dv), dualtype(dv)')

    ######################
    # Generic Arithmetic #
    ######################
    for op = (:*,:.*,
              :/,:./,
              :+,:.+,
              :-,:.-,
              :^,:.^)
        @eval begin
            ($op)(dv::DiracVector, c) = DiracVector(($op)(coeffs(dv), c), basis(dv), dualtype(dv))
            ($op)(c, dv::DiracVector) = DiracVector(($op)(c, coeffs(dv)), basis(dv), dualtype(dv))         
        end
    end

    ############################
    # Convenience Constructors #
    ############################
    one_at_ind!(arr, i) = setindex!(arr, one(eltype(arr)), i)
    single_coeff(i, lens...) = one_at_ind!(zeros(lens), i)
    diraccoeffs(i, len, ::Type{Ket}) = single_coeff(i, len)
    diraccoeffs(i, len, ::Type{Bra}) = single_coeff(i, 1, len)

    diracvec(i::Int, b::AbstractLabelBasis, D=Ket) = DiracVector(diraccoeffs(i, length(b), D), b, D)
    diracvec(tup::Tuple, b::AbstractLabelBasis, D=Ket) = DiracVector(diraccoeffs(getpos(b, tup), length(b), D), b, D)

    # `s` is the index at which 
    # the one coefficient resides;
    # if `s` is a tuple, it will be
    # treated like a label, and the
    # coefficient will be placed at
    # the label's position. If `s`
    # is a number, it will 
    # be treated like an index
    # into the coefficient
    # array
    ketvec(s, basis::FockBasis) = diracvec(s, basis, Ket)
    ketvec(s, lens::Tuple) = ketvec(s, FockBasis(lens))
    ketvec(s, lens...=s) = ketvec(s, lens)
    ketvec(s::Tuple) = ketvec(s, s)
    ketvec(s::Number) = ketvec(s, tuple(s-1))

    bravec(s, basis::FockBasis) = diracvec(s, basis, Bra)
    bravec(s, lens::Tuple) = bravec(s, FockBasis(lens))
    bravec(s, lens...=s) = bravec(s, lens)
    bravec(s::Tuple) = bravec(s, s)
    bravec(s::Number) = bravec(s, tuple(s-1))

export DiracVector,
    ketvec,
    bravec,
    structure,
    dualtype