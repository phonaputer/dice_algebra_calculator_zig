# Dice Algebra Calculator - Written in Zig

A dice algebra expression lexer, parser, & executor written in Zig. 

The purpose of writing this application is to have fun trying out Zig by writing a simple application.
A dice algebra calculator (including lexing, parsing, and execution of string expressions) was selected as something that is probably complex enough to be interesting yet is simple enough to do in an afternoon.

It's also something that can be extended later if that seems like it would be fun (e.g. this application could run a GUI window in which expressions can be input & a breakdown of the results can be shown, etc.).

And finally this is a project which can be done in any language, which allows comparing and constrasting (also fun).

The goal here is to write a program with source code which is as clean as possible (not an easy task without an old hand to ask questions to) and learn about tooling around the language. 

## What is "Dice Algebra?"

Dice algebra consists of simple mathematical expressions where operands may be a "dice roll."

A simple dice roll takes the format `xdy` (or `xDy`) where both `x` and `y` must be integers. 
`xdy` means that a `y`-sided die will be rolled `x` times. For example, `3d6` will roll a 6-sided die three times and sum the results.

The leading `x` may be omitted if it is 1. For example, `d4` rolls a 4-sided die one time.


When rolling more than one die it is possible to keep only the lowest `n` rolls or the highest `n` rolls by appending `ln` or `hn`, respectively, to the roll. For example, `2d20h1` will roll two 20-sided dice and keep the highest result.

In addition to rolling dice, it is possible to include integers, addition `+`, subtraction `-`, multiplcation `*`, integer division `/`, and parenthetical expressions `(...)`. For example, `(2d6 + 5) * 10` will roll two 6-sided die, add five to that result, then mutiply that result by ten. 

All integers must be positive (or 0).

## ANTLR Grammar

The above dice algebra format can be expressed as the following ANTLR 4 grammar. This grammar is more-or-less what this application targets when parsing input.

```ANTLR
grammar DiceAlgebra;

// Parser

add : mult (('+' | '-') mult)* ;
mult : atom (('*' | '/') atom)* ;
atom : (roll | '(' add ')') ;
roll : (integer | longroll | shortroll) ;
longroll : integer D integer ((H integer | L integer))? ;
shortroll : D integer ; 
integer : NUMBER ;

// Lexer

WHITESPACE : ' ' -> skip ;
NUMBER : [0-9]+ ;
D : 'd' | 'D' ;
PLUS : '+' ;
MINUS : '-' ;
MULT: '*' ;
DIV : '/' ;
OPENPAREN : '(' ;
CLOSEPAREN : ')' ;
H : 'h' | 'H' ;
L: 'l' | 'L' ;
```

## How to Run

The dice algebra calculator compiles to a CLI application binary.
When the CLI is executed, it prompts the user for a dice algebra expression. 
Then it computes the expression and prints the result.

An example invocation looks like:

```
> ./dice_algebra_calculator
Please enter a dice algebra expression: 2d6 + 10

Your result is: 14
```

The binary may be invoked with the `--v` flag for verbose output (which prints all dice rolls):

```
> ./dice_algebra_calculator --v
Please enter a dice algebra expression: 2d6 + 10

Rolling 2d6...
You rolled: 3
You rolled: 1

Your result is: 14
```

## How to Build Locally

To compile the `dice_algebra_calculator` binary, execute the following command from the root of this repository.
You must have [Zig](https://ziglang.org/) installed for this to work.

```
zig build install
```

This will create a compiled binary file in the `./zig-out/bin` directory.

## How to Run the Unit Tests

The unit tests can be run by executing the following command from the root of this repository.

```
zig build test --summary all
```

## Retrospective Thoughts

I have heard that Zig is intended as a competitor to C. 
I can see what people mean when they say that.

Now that I've coded this toy compiler in Zig, C, and C++, for this particular task I would rate Zig as being a lot easier than C but still significantly harder than C++. 

In terms of time spent coding, Zig took a bit longer than C++ but not wildly longer. 
By contrast this took me forever to do using C (including fixing all bugs and memory leaks).
For incidence of memory leaks and other bugs, I had more leaks in C but I still had plenty in Zig. 
In C++ due to the convenience of RAII and smart pointers I did not have a single memory leak.
Just as a quick metric, the Zig code was 713 lines (excluding tests), C++ was 716, and C was 1456.

Given those experiences, for me personally I would say Zig is a great replacement for C (if it truly shapes up in terms of performance). 
But I would not consider it a replacement for a langauge like C++.
That may change as Zig moves closer to its 1.0.0 release, but given the language's focus on simplicity I kinda doubt it.
For myself, I like having the advanced features that C++ brings to the table such as OOP & exceptions.
And those smart pointers make preventing memory leaks almost too easy. 
(After hearing all the negative things I've heard about C++ I find it hard to believe I did not screw something up, but based on the Clang memory sanitizer and Valgrind apparently I did not. Beginner's luck?)
I wouldn't trade easy development and error-free code for "simplicity" or cool modern syntax (it sure is cool!).

One place where I would say Zig shines is the tooling. 
Working with the Zig compiler, unit tests, etc. is a lot more pleasant than monkeying around with CMake.
That said, CMake wasn't "terrible" and C++ has libraries for things like testing so this doesn't quite make Zig a "C++ killer" for me.

At the end of the day, if I had to rate which high-level-langauge-with-manual-memory-management I'd prefer to use on a work project I'd say C++ > Zig > C.

One other minor thought I had while working on this was - as a guy who writes a lot of Go at work I found a number of nice little bits of syntax in Zig that I wish were in Go (enums, `try`, exhaustive `switch` statements, etc.).
It made me wonder if a garbage collected version of Zig would be a good Go replacement.
