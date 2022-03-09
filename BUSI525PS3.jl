using CSV, Plots,JuMP, Random, Statistics, Bootstrap, Distributions, LinearAlgebra,Dates,DataFrames,Gurobi,DataFramesMeta,StatsBase

function Stambaugh(T,rho_uv;B=250,alpha=0.0,beta=0.015,sigma_u=0.053,theta=0,sigma_v=0.044,rho=0.98)
    d1 = MvNormal(zeros(2),[sigma_u^2. rho_uv*sigma_u*sigma_v;rho_uv*sigma_u*sigma_v sigma_v^2])
    est_beta = zeros(B)
    for b = 1:B
        uv = rand(d1, T)
        u = uv[1,:]
        v = uv[2,:]
        x = zeros(T)
        r = zeros(T)
        for t = 1:T
            if t == 1
                x[t] = theta + rho*0.0 + v[t]
                r[t] = alpha + beta*0.0 + u[t]
            else
            x[t] = theta + rho*x[t-1] + v[t]
            r[t] = alpha + beta*x[t-1] + u[t]
            end
        end
        X = hcat(ones(T),x)
        estimator = (X'X)\(X'r)
        est_beta[b] = estimator[2]
    end
    beta_percentiles = [percentile(est_beta, 5),mean(est_beta),percentile(est_beta,95)]
    return beta_percentiles
end

Ts = 120:120:1200
beta_plots = zeros(length(Ts),3)
for i=1:length(Ts)
    beta_plots[i,:]=Stambaugh(Ts[i],0.8)
end
p1 = plot(xlabel="T",ylabel="Est. Beta")
p1 = plot!(Ts,beta_plots[:,1],label = "5% percentile")
p1 = plot!(Ts,beta_plots[:,2],label = "Mean")
p1 = plot!(Ts,beta_plots[:,3],label = "95% percentile")

rho_uvs = [-0.2,-0.5,-0.8]
beta_plots_corr = zeros(length(Ts),length(rho_uvs))
for j = 1:length(rho_uvs)
    for i=1:length(Ts)
        beta_plots_corr[i,j]=Stambaugh(Ts[i],rho_uvs[j])[2]
    end
end

p2 = plot(xlabel="T",ylabel="Est. Beta")
p2 = plot!(Ts,beta_plots_corr[:,1],label = "corr = -0.2")
p2 = plot!(Ts,beta_plots_corr[:,2],label = "corr = -0.5")
p2 = plot!(Ts,beta_plots_corr[:,3],label = "corr = -0.8")
