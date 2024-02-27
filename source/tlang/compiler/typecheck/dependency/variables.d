module tlang.compiler.typecheck.dependency.variables;

import tlang.compiler.typecheck.dependency.core;
import tlang.compiler.symbols.data;
import std.conv : to;

/**
* This module holds types related to variable declarations
* at the module-level, class-level (static and instance)
* and struct-level
*/

//TODO: See how needed these REALLY are (see issue #55)

public class VariableNode : DNode
{
    private Variable variable;

    this(Variable variable)
    {
        super(variable);

        this.variable = variable;

        initName();
    }

    private void initName()
    {
        name = to!(string)(variable);
    }
}

public class FuncDecNode : DNode
{
    private Function funcHandle;

    this(Function funcHandle)
    {
        super(funcHandle);

        this.funcHandle = funcHandle;
        initName();
    }

    private void initName()
    {
        name = "FuncHandle:"~to!(string)(funcHandle);
    }
}

public class ModuleVariableDeclaration : VariableNode
{
    this(Variable variable)
    {
        super(variable);

        initName();
    }

    private void initName()
    {
        name = "(S) "~to!(string)(variable);
    }
}

public class StaticVariableDeclaration : VariableNode
{
    this(Variable variable)
    {
        super(variable);

        initName();
    }

    private void initName()
    {
        name = "(S) "~to!(string)(variable);
    }
}

public class VariableAssignmentNode : DNode
{
    private VariableAssignment variableAssignment;

    this(VariableAssignment variableAssignment)
    {
        super(variableAssignment);

        this.variableAssignment = variableAssignment;
        initName();
    }

    private void initName()
    {
        /* get the associated variable */
        Variable associatedVariable = variableAssignment.getVariable();

        name = to!(string)(associatedVariable)~" (assignment)";
    }
}