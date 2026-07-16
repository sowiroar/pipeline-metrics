function [wsdm,wsgc,ham_dist,mimat,hdmat,cmimat,omat] = multi_fc(data, hoeffdingFromCopula)
% Computes multiple functional connectivity measures based on linear,
% non-linear, weighted and non-weighted dependencies measures.
% Pearson, WSDM, WSMI, GCMI, HoeffI, CMI(x,y,z), O-Info(x,y,z)
%
% ------------------------------------------------------------------------
% WSDM provided by (c) Sebastian Moguilner
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6060104/
%
% and a weighted symbolic Gaussian Copulas correlation matrix
%
% data = T x N matrix
% hoeffdingFromCopula = True if wants to calculate the metrics that depend on 'hoeffdingFromCopula' (3). False otherwise

[T,N] = size(data);
ent_fun = @(x,y) 0.5.*log((2*pi*exp(1)).^(x).*y);

% Initializing wsDM (if hoeffdingFromCopula is desired)
if hoeffdingFromCopula
    ds = [1;1];
    mult = 1;
    co = IHoeffding_initialization(mult);
end

% Symbolization and Computing Hamming Distances
a_ids = (data(1:end-2,:)<data(2:end-1,:)) & (data(2:end-1,:)<data(3:end,:));
b_ids = (data(1:end-2,:)>data(2:end-1,:)) & (data(2:end-1,:)>data(3:end,:));
symb_mat = zeros(T-2,N);
symb_mat = symb_mat +  a_ids.*'a' + b_ids.*'b';
ham_dist = 1- pdist2(symb_mat',symb_mat','hamming');

% Computation of copula
[~,sortid] = sort(data,1); % sort data and keep sorting indexes
[~,copdata] = sort(sortid,1); % sorting sorting indexes
copdata = copdata./(T+1); % normalization to have data in [0,1]

% Computing Gaussian Copula Covmat and bias corrector
bc2 = gaussian_ent_biascorr(2,T); % bias corrector
bc1 = gaussian_ent_biascorr(1,T);
bcN = gaussian_ent_biascorr(N,T);
bcNmin1 = gaussian_ent_biascorr(N-1,T);
bcNmin2 = gaussian_ent_biascorr(N-2,T);
gaussian_data= norminv(copdata);% uniform data to gaussian data
gaussian_data(isinf(gaussian_data)) = 0; % removing inf
gc_covmat = (gaussian_data'*gaussian_data) / (T - 1); % GC covariance matrix

% linear indices of pairwise interactions 
k_ints = nchoosek(1:N,2);
nints = length(k_ints);
linids = sub2ind([N,N],k_ints(:,1),k_ints(:,2));  %linear index of mi matrix

% Loop for computing MI and Hoeffding Distance
mimat = zeros(N);
hdmat = mimat;
cmimat = mimat;
mi = zeros(nints,1);
cmi = mi;
hd = mi;

% Preparing data
detmv = det(gc_covmat);
single_vars = diag(gc_covmat);
var_ents = ent_fun(1,single_vars) - bc1;
sys_ent = ent_fun(N,detmv) - bcN; % total system entropy
reg_id = 1:N;
% delete(gcp('nocreate'))
% parpool(2);
for i = 1:nints
    % Mutual Info
    thiscovmat = gc_covmat(k_ints(i,:),k_ints(i,:));
    this_detmv = det(thiscovmat); % determinant    
    this_var_ents = var_ents(k_ints(i,:));
    thissys_ent = ent_fun(2,this_detmv) - bc2;

    mi(i) = sum(this_var_ents) - thissys_ent; 
    
    % Conditional Mutual Info
    sel_id = reg_id;
    sel_id1 = reg_id;
    sel_id2 = reg_id;
    sel_id(k_ints(i,:))=[]; % region indices minus x and y
    sel_id1(k_ints(i,1))=[]; % region indices minus x 
    sel_id2(k_ints(i,2))=[]; % region indices minus y    
    
    xzent = ent_fun(N-1,det(gc_covmat(sel_id1,sel_id1))) - bcNmin1; % entropy of whole minus x
    yzent = ent_fun(N-1,det(gc_covmat(sel_id2,sel_id2))) - bcNmin1; % entropy of whole minus y
    zent = ent_fun(N-2,det(gc_covmat(sel_id,sel_id))) - bcNmin2; % entropy of whole minus x and y
    
    cmi(i) = xzent + yzent - sys_ent - zent;    
    
    % Hoeffding I
    if hoeffdingFromCopula
        hd(i) = IHoeffding_estimation_from_copula(copdata(:,k_ints(i,:))',ds,co);
    end
    
    
end
mimat(linids) = mi;
mimat = mimat + mimat';

cmimat(linids) = cmi;
cmimat = cmimat + cmimat';

omat = mimat - cmimat; 

hdmat(linids) = hd;
hdmat = hdmat + hdmat';

% Computing wighted symbolic metrics
wsdm = ham_dist.*hdmat;
wsgc = ham_dist.*mimat;
