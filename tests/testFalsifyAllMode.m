% falsify two specs on a toy model whose state is constant (x(t)=x0) in
% 'any' and 'all' modes, and print the result for each spec.
x = stl('x',1);
phi1 = globally(~(x(1) >= 0.3 & x(1) <= 0.7), interval(0,1));
phi2 = globally(~(x(1) >= 1.3 & x(1) <= 1.7), interval(0,1));
modes = {'any','all'};
for m = 1:numel(modes)
    % initialize seeds
    rng(0)
    pyrunfile("seed.py")
    kfModel = KF(@constantModel);
    kfModel.R0 = interval(0,2);
    kfModel.T = 1;
    kfModel.dt = 0.05;
    kfModel.ak.dt = 0.2;
    kfModel.ak.nObs = 8;
    kfModel.ak.gridSlices = 2;
    kfModel.ak.rank = [1,4,1];
    kfModel.maxSims = 30;
    kfModel.spec = [specification(phi1,'logic'); specification(phi2,'logic')];
    kfModel.falsifyMode = modes{m};
    solns = falsify(kfModel);
    soln = solns{1};
    fprintf('\nmode %s: falsified %d/%d specs after %d simulations\n', modes{m}, soln.numSpecsFalsified, soln.totalSpecs, soln.sims);
    specResults = soln.specResults.values('cell');
    for i = 1:numel(specResults)
        r = specResults{i};
        fprintf('  phi%d falsified: %d, at simulation: %d, x0: %.3f\n', i, r.falsified, r.falsifiedAtSim, r.best.x(1));
    end
end

function [tout, yout] = constantModel(T, x0)
tout = linspace(0,T,21)';
yout = repmat(x0(:)', numel(tout), 1);
end
