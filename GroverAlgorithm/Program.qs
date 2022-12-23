namespace Quantum.GroverAlgorithm {

    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Preparation;

    @EntryPoint()
    operation FactorizeWithGrover(number: Int) : Unit {
        // Define the oracle that for the factoring problem
        let markingOracle = MarkDivisor(number, _, _);
        let phaseOracle = ApplyMarkingOracleAsPhaseOracle(markingOracle, _);

        // Bit-size of the number to factorize
        let size = BitSizeI(number);

        // Estimate of the number of solutions
        let solutionCount = 4;

        // The number of iterations can be computed using the formula
        let iterations = Round(PI() / 4.0 * Sqrt(IntAsDouble(size) / IntAsDouble(solutionCount)));

        // Initialize the register to run the algorithm
        use (register, output) = (Qubit[size], Qubit());
        mutable isCorrect = false;
        mutable answer = 0;

        // Use a Repeat-Until-Succeed loop to iterate unitl the solution is valid
        repeat {
            GroverSearch(register, phaseOracle, iterations);
            let res = MultiM(register);
            set answer = BoolArrayAsInt(ResultArrayAsBoolArray(res));

            // See if the result is a solution with the oracle
            markingOracle(register, output);
            if (MResetZ(output) == One and answer != 1 and answer != number) {
                set isCorrect = true;
            }
            ResetAll(register);
        } until isCorrect;

        // Print out the answer
        Message($"The number {answer} is a factor of {number}");
    }

    operation MarkDivisor(dividend: Int, divisorRegister: Qubit[], target: Qubit) : Unit is Adj + Ctl {
        // Calculate the bit-size of the dividend
        let size = BitSizeI(dividend);

        // Allocate two new qubit registers for the dividend and the result
        use dividendQubits = Qubit[size];
        use resultQubits = Qubit[size];

        // Create new LittleEndian instances from the registers to use DivideI
        let xs = LittleEndian(dividendQubits);
        let ys = LittleEndian(divisorRegister);
        let result = LittleEndian(resultQubits);

        // Start a within-apply statement to perfrom the operation
        within {
            // Encode the dividend in the register
            ApplyXorInPlace(dividend, xs);

            // Apply the division operation
            DivideI(xs, ys, result);

            // Flip all the qubits from the remainder
            ApplyToEachA(X, xs!);
        } apply {
            // Apply a controlled NOT over the flipped remainder
            Controlled X(xs!, target);

            // The target flips if and only if the remainder is 0
        }
    }

    operation ApplyMarkingOracleAsPhaseOracle(markingOracle: (Qubit[], Qubit) => Unit is Adj, register: Qubit[]) : Unit is Adj {
        use target = Qubit();
        within {
            X(target);
            H(target);
        } apply {
            markingOracle(register, target);
        }
    }

    operation ReflectAboutUniform(inputQubits: Qubit[]) : Unit {
        within {
            ApplyToEachA(H, inputQubits);
            ApplyToEachA(X, inputQubits);
        } apply {
            Controlled Z(Most(inputQubits), Tail(inputQubits));
        }
    }

    operation GroverSearch(register: Qubit[], phaseOracle: (Qubit[]) => Unit is Adj, iterations: Int) : Unit {
        // Prepare register into uniform superposition
        ApplyToEach(H, register);

        // Start Grover's loop
        for _ in 1 .. iterations {
            // Apply phase oracle for the task
            phaseOracle(register);

            // Apply Grover's diffusion operator
            ReflectAboutUniform(register);
        }
    }
}
