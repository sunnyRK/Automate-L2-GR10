/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer } from "ethers";
import { Provider } from "@ethersproject/providers";

import type { ILendingPoolAddressesProvider } from "../ILendingPoolAddressesProvider";

export class ILendingPoolAddressesProvider__factory {
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ILendingPoolAddressesProvider {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ILendingPoolAddressesProvider;
  }
}

const _abi = [
  {
    inputs: [],
    name: "getLendingPool",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];