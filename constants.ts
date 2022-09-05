import deploymentJSON from './deployments.json';

export const DEPLOYMENTS_PATH = 'deployments.json';
export const DEPLOYMENTS_FILE = deploymentJSON ?? {};

export type TMeta = {
    name: string;
    address: string;
};
export type TContract = {
    name: string;
    address: string;
    meta: TMeta;
};

export type TDeployment = {
    [chain: string]: TContract[];
};
