import { existsSync, readFileSync } from 'node:fs';

export const DEPLOYMENTS_PATH = 'deployments.json';
export const DEPLOYMENTS_FILE = existsSync(DEPLOYMENTS_PATH)
    ? JSON.parse(readFileSync(DEPLOYMENTS_PATH, 'utf8'))
    : {};

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
