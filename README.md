# P2P System and Blockchain Project Report

This project report is for a Master's Degree Course in Cybersecurity at the University of Pisa. The project focuses on re-imagining the Battleship game on the Ethereum blockchain, where a wide range of options are made possible. The report covers the implementation choices, guide demo, evaluation of the gas cost, vulnerabilities analysis, and conclusion.

## Introduction
This project focuses on a Battleship game, a traditional game in which two players position a fixed number of ships and after that phase try to find the other player’s ships. Ship placement and tactical engagement are the two separate phases of the game, which are defined by a secret battlefield and hidden information. The Ethereum blockchain is where this project seeks to re-imagine the Battleship experience. The Battleship experience is transferred to the Ethereum blockchain, where a wide range of options are made possible.

## Implementation Choices
The project uses two main contracts, the Battleship.sol and the Battleship-Storage contract, which store the main variables and information that the Battleship contract uses to achieve and play the game in a correct way. The game logic is inside the Battleship-Storage contract, and it incorporates a reward system for winners, allowing for the secure and timely distribution of tokens or cryptocurrency from the smart contract's balance.

## Guide Demo
The report also explains how to test the game using Truffle with Ganache. The game representation uses a text-based representation of the board. The players continue those attacks up to the moment in which all the ships are sunk. Every time that the attack function is called a different player must have called it.

## Evaluation of the Gas Cost
Analyzing the results of the deploy battleship.js migration script will allow us to determine how much gas is used by the smart contract’s functions. The cost of deploying the two contracts in EUR is 26.21 EUR. The gas cost of the attack() method might vary based on the size of the game board and the complexity of the attack.

## Vulnerabilities Analysis and Conclusion
The Slither analysis program has discovered a number of potential vulnerabilities, including state variables not in use, unused features, missing statements requiring, and incorrect application of modifiers. It is suggested to analyze the input data to make sure that the ship locations are appropriate in order to close this issue. To achieve this, confirm that the ship positions do not overlap and that they are contained inside the boundaries of the game board.

Overall, this project has successfully shifted the traditional game of Battleship to the Ethereum blockchain by using its unique features like transparency, tamper resistance, and the ability to incorporate a reward system for winners.
