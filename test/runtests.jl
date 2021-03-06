using FEDVR
using LinearAlgebra
using Test

function vecdist(a::AbstractVector, b::AbstractVector,
                 ϵ = eps(eltype(a)))
    δ = √(sum(abs2, a-b))
    δ, δ/√(sum(abs2, a .+ ϵ))
end

@testset "grid" begin
    N = 11
    n = 5
    breaks = range(0, stop=1, length=N)
    grid = FEDVR.Grid(breaks, n)

    @test minimum(grid) == 0
    @test maximum(grid) == 1

    @testset "dirichlet0" begin
        # We want the endpoints of the finite elements to match up exactly
        @test grid.X[1:end-1,end] == grid.X[2:end,1]

        @test grid.N[1] == 1/√(grid.W[1])
        @test grid.N[2,1] == 1/√(grid.W[1,end]+grid.W[2,1])

        @test elcount(grid) == N-1
        @test elems(grid) == 1:N-1
        @test order(grid) == n
        @test basecount(grid) == (N-1)*n - (N-2) - 2 # Dirichlet0 boundary conditions, hence -2
        Xp = locs(grid)
        @test length(Xp) == basecount(grid)
        @test Xp[1] > breaks[1]
        @test Xp[end] < breaks[end]

        gW = weights(grid)
        gN = FEDVR.boundary_sel(grid, [grid.N[:,1:end-1]'[:]..., grid.N[end]])
        @test vecdist(sqrt.(gW[2:end-1]),
                      1 ./ gN[2:end-1])[1] < eps(Float64)
    end

    @testset "intervals" begin
        for nn = 300:301
            x = range(breaks[1], stop=breaks[end], length=nn)
            sel = 1:1
            sel = FEDVR.find_interval(grid.X, x, 1, sel)
            @test x[sel[1]] == breaks[1]
            for i = elems(grid)[1:end-1]
                sel = FEDVR.find_interval(grid.X, x, i, sel)
                @test x[sel[1]] >= breaks[i]
                @test x[sel[end]] < breaks[i+1]
            end
            i = elcount(grid)
            sel = FEDVR.find_interval(grid.X, x, i, sel)
            @test x[sel[1]] >= breaks[i]
            @test x[sel[end]] == breaks[end]
        end
    end

    @testset "misc" begin
        @test !isempty(string(grid))

        @test begin
            using RecipesBase
            RecipesBase.apply_recipe(Dict{Symbol,Any}(), grid)
            true
        end
    end

    @testset "dirichlet1" begin
        N = 11
        n = 5
        breaks = range(0, stop=1, length=N)
        grid = FEDVR.Grid(breaks, n, :dirichlet1, :dirichlet1)

        # We want the endpoints of the finite elements to match up exactly
        @test grid.X[1:end-1,end] == grid.X[2:end,1]

        @test grid.N[1] == 1/√(grid.W[1])
        @test grid.N[2,1] == 1/√(grid.W[1,end]+grid.W[2,1])

        @test elcount(grid) == N-1
        @test elems(grid) == 1:N-1
        @test order(grid) == n
        @test basecount(grid) == (N-1)*n - (N-2)
        Xp = locs(grid)
        @test length(Xp) == basecount(grid)
        @test Xp[1] == breaks[1]
        @test Xp[end] == breaks[end]
    end
end

@testset "lagrange" begin
    N = 11
    n = 5
    breaks = range(0, stop=1, length=N)
    grid = FEDVR.Grid(breaks, n)
    e = m -> vec([zeros(m-1);1;zeros(n-m)])
    for i = elems(grid)
        for m = 1:n
            @test FEDVR.lagrange(grid.X[i,:], m, grid.X[i,m]) == 1
            @test FEDVR.lagrange(grid.X[i,:], m, grid.X[i,:]) == e(m)
        end
    end

    @test FEDVR.δ(-1, -1) == 1
    @test FEDVR.δ(-1, 1) == 0
    @test FEDVR.δ(0, 0) == 1
    @test FEDVR.δ(0, 1) == 0

    f = x -> x^4
    g = x -> 4x^3

    L′ = FEDVR.lagrangeder(grid)

    for i = elems(grid)
        c = f.(grid.X[i,:])
        c′ = L′[i,:,:]'c
        c′a = g.(grid.X[i,:])
        @test vecdist(c′, c′a)[2] < 1e-13
    end
end

@testset "basis" begin
    N = 11
    n = 5
    breaks = range(0, stop=1, length=N)
    for bdrl = [:dirichlet0, :dirichlet1]
        for bdrr = [:dirichlet0, :dirichlet1]
            basis = FEDVR.Basis(breaks, n, bdrl, bdrr)

            x = locs(basis.grid)
            χ = basis(x)
            dχ = diag(χ)
            gN = [basis.grid.N[:,1:end-1]'[:]..., basis.grid.N[end]]
            @test dχ == FEDVR.boundary_sel(basis.grid, gN)

            @testset "misc" begin
                @test !isempty(string(basis))

                @test begin
                    using RecipesBase
                    RecipesBase.apply_recipe(Dict{Symbol,Any}(), basis)
                    true
                end
            end
        end
    end

    @testset "eval on subset" begin
        basis = FEDVR.Basis(breaks, n)
        x₁ = range(0, stop=1, length=35)
        x₂ = x₁[8:19]
        x₃ = range(-1, stop=-0.5, length=11)
        χ₁ = basis(x₁)
        χ₂ = basis(x₂)
        χ₃ = basis(x₃)
        δχ = χ₁[8:19,:] - χ₂
        @test norm(δχ) == 0
        @test norm(χ₃) == 0
    end
end

@testset "projections" begin
    breaks = range(0, stop=1, length=11)
    n = 5
    basis = FEDVR.Basis(breaks, n, :dirichlet1, :dirichlet1)
    x = range(minimum(breaks), stop=maximum(breaks), length=301)
    χ = basis(x)

    f = x -> x^3 - 7x^2 + x^4 + 2
    ϕ = project(f, basis)

    @test vecdist(f.(x), χ*ϕ)[2] < 10eps(Float64)
end

# @testset "derivatives" begin
#     N = 30
#     n = 10
#     L = 5.0
#     xx = range(0, stop=L, length=N+1)
#     basis = FEDVR.Basis(xx, n)
#     T = kinop(basis)
#     x = locs(basis.grid)
#     χ = basis(x)

#     mmax = 30
#     λ,ϕ = eigs(T,which=:SR,nev=mmax)
#     m = eachindex(λ)
#     λa = 0.5*(π*m/L).^2

#     @test vecdist(real.(λ), λa)[2] < 1e-11

#     for m = 1:mmax
#         ϕa = √(2/L) * sin.(m*π*x/L)
#         ϕm = real(ϕ[:,m])
#         ϕm *= sign(ϕm[1])
#         @test vecdist(ϕa, χ*ϕm)[2] < 1e-8
#     end
# end
