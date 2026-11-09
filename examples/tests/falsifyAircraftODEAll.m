function falsifyAircraftODEAll()

bench.kfModel = @modelAircraftODE;
x = stl('x',3);
bench.requirements = {; ...
    "phi1", implies(globally(x(1) >=250 & x(1) <=260,interval(1,1.5)),globally(~(x(1)>=230 & x(1)<=240),interval(3,4))); ...
    "phi2",globally(x(3)>0,interval(0,4)); ...
    };

% initialize seeds
rng(0)
pyrunfile("seed.py")

kfModel = bench.kfModel();
req = bench.requirements;
specs = specification(req{1, 2},'logic');
for i = 2:size(req, 1)
    specs(end+1,1) = specification(req{i, 2},'logic');
end

kfModel.spec = specs;
kfModel.falsifyMode = 'all';
kfModel.runs = 1;
kfModel.verb = 1;
kfSolns = falsify(kfModel);
soln = kfSolns{1};

printInfo(kfSolns)

% specResults keys are the CNF-converted specs (see initialize.m), stored in
% the given order, so index the results by position
specResults = soln.specResults.values('cell');
for i = 1:size(req, 1)
    specResult = specResults{i};
    fprintf('Property %s falsified: %d\n', req{i, 1}, specResult.falsified);
    fprintf('Best robustness for %s: %.3f\n', req{i, 1}, specResult.best.rob);
end

end
