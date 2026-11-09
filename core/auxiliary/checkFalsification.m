function [soln,falsified,robustness,Bdata,newGlobalBest,bestSpec]=checkFalsification(soln,x,u,t,specs,tcp,inputInterpolation,U,method,verb)
% CHECKFALSIFICATION Checks if a given trajectory falsifies a set of specifications.
%
%   [soln, falsified, robustness, Bdata, newGlobalBest] = checkFalsification(soln, x, u, t, specs, inputInterpolation, method, verb)
%
% Inputs:
%   soln - Struct containing information about the current falsification process.
%   x - State trajectory.
%   u - Input trajectory.
%   t - Time points corresponding to the trajectories.
%   specs - CORA specification object.
%   inputInterpolation - Interpolation method for input trajectories.
%   method - String indicating the method used for falsification.
%   verb - Verbosity level for printing messages.
%
% Outputs:
%   soln - Updated struct with information about the current falsification process.
%   falsified - Logical indicating if any specification ('any' mode) or all
%               specifications ('all' mode) have been falsified.
%   robustness - Minimum robustness value over (remaining) specifications.
%   bestSpec - Specification with minimum robustness over (remaining) specifications.
%   Bdata - Data associated with the falsification for each specification, e.g., predicates and times.
%   newGlobalBest - Logical indicating if a new best solution  has been found.
%
% Description:
%   This function checks if a given trajectory falsifies a set of specifications.
%   The specifications can be of different types, including unsafe sets, safe sets,
%   and logical formulas. The function evaluates the trajectory against each
%   specification and updates the falsification status, robustness value,
%   and relevant data. Additionally, it checks if the current solution is better
%   than the best solution found so far and updates the soln struct accordingly.
%
% See also:
%   bReachRob, interp1, vprintf
%
% Author: Abdelrahman Hekal
% Written: 28-February-2023
% Last update: ---

falsified=false; bestRob=inf; bestSpec=[];
Bdata=dictionary(specs,struct); newGlobalBest=false;
if ~isempty(u)
    interpU = interp1(u(:,1),u(:,2:end),t,inputInterpolation); %interpolate input at same time points as trajectory
    usim = interp1(u(:,1),u(:,2:end),tcp,inputInterpolation,"extrap"); %interpolate and extrapolate input points
    usim = max(U.inf',min(U.sup',usim)); %ensure that extrapolation is within input bounds
else
    interpU=u;
    usim=u;
end
for ii=1:numel(specs)
    spec=specs(ii);
    specRob=inf;
    specFalsified=false;
    specBdata=NaN;
    % different types of specifications
    %TODO, compute robustness for sets
    if strcmp(spec.type,'unsafeSet')
        specFalsified = any(spec.set.contains(x'));
    elseif strcmp(spec.type,'safeSet')
        specFalsified = ~all(spec.set.contains(x'));
    elseif strcmp(spec.type,'logic')
        [specBdata,~,specRob] = bReachRob(spec,t,x,interpU');
        vprintf(verb,3,"robustness value: %.3f after %d simulations with method: %s \n",specRob,soln.sims,method)
        if specRob <= 0 %if less than or equal zero
            specFalsified=true;
        end
    end
    Bdata(spec)=struct('falsified',specFalsified,'robustness',specRob,'Bdata',specBdata);

    %store best and first falsifying trace for each spec
    specResult = soln.specResults(spec);
    if specRob < specResult.best.rob || (specFalsified && isinf(specResult.best.rob))
        specResult.best.rob=specRob; specResult.best.x=x; specResult.best.u=usim; specResult.best.t=tcp; specResult.best.spec=spec;
    end
    if specFalsified && ~specResult.falsified
        specResult.falsified=true; specResult.falsifiedAtSim=soln.sims;
        specResult.falsifyingTrace.rob=specRob; specResult.falsifyingTrace.x=x; specResult.falsifyingTrace.u=usim; specResult.falsifyingTrace.t=tcp; specResult.falsifyingTrace.spec=spec;
    end
    soln.specResults(spec)=specResult;

    if specRob<=bestRob
        bestRob=specRob;
        bestSpec=spec;
    end
    if specRob < soln.best.rob
        vprintf(verb,2,"new best robustness!: %.3f after %d simulations due to: %s \n",specRob,soln.sims,method)
        soln.best.rob=specRob;
        soln.best.x=x; soln.best.u=usim; soln.best.t=tcp; soln.best.spec=spec;
        newGlobalBest=true; %found a new best soln
    end
end
soln.remainingSpecs=getRemainingSpecs(specs,soln.specResults);
soln.numSpecsFalsified=numel(specs)-numel(soln.remainingSpecs);
if strcmp(soln.falsifyMode,'all')
    falsified=isempty(soln.remainingSpecs);
    [robustness,bestSpec]=getRemainingRobustness(Bdata,soln.remainingSpecs,bestRob,bestSpec);
else
    falsified=soln.numSpecsFalsified>0;
    robustness=bestRob;
end
soln.falsified=falsified;
end

function remainingSpecs=getRemainingSpecs(specs,specResults)
%get specs that have not yet been falsified
mask=false(numel(specs),1);
for ii=1:numel(specs)
    mask(ii)=~specResults(specs(ii)).falsified;
end
remainingSpecs=specs(mask);
end

function [robustness,bestSpec]=getRemainingRobustness(Bdata,remainingSpecs,bestRob,bestSpec)
%get minimum robustness and corresponding spec over specs that have not yet been falsified
if isempty(remainingSpecs)
    robustness=bestRob;
    return;
end
robustness=inf;
for ii=1:numel(remainingSpecs)
    if Bdata(remainingSpecs(ii)).robustness<=robustness
        robustness=Bdata(remainingSpecs(ii)).robustness;
        bestSpec=remainingSpecs(ii);
    end
end
end