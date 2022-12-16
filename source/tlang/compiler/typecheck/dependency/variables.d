module compiler.typecheck.dependency.variables;

import compiler.typecheck.dependency.core;
import compiler.symbols.data;

/**
* This module holds types related to variable declarations
* at the module-level, class-level (static and instance)
* and struct-level
*/

//TODO: See how needed these REALLY are (see issue #55)

public class VariableNode : DNode
{
    private Variable variable;

    this(DNodeGenerator dnodegen, Variable variable)
    {
        super(dnodegen, variable);

        this.variable = variable;

        initName();
    }

    private void initName()
    {
        name = resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
    }

    
}

public class FuncDecNode : DNode
{
    private Function funcHandle;

    this(DNodeGenerator dnodegen, Function funcHandle)
    {
        super(dnodegen, funcHandle);

        this.funcHandle = funcHandle;

        initName();
    }

    private void initName()
    {
        name = "FuncHandle:"~resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
    }

    
}

public class ModuleVariableDeclaration : VariableNode
{
    this(DNodeGenerator dnodegen, Variable variable)
    {
        super(dnodegen, variable);

        initName();
    }

    private void initName()
    {
        name = "(S) "~resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
    }
}

public class StaticVariableDeclaration : VariableNode
{
    this(DNodeGenerator dnodegen, Variable variable)
    {
        super(dnodegen, variable);

        initName();
    }

    private void initName()
    {
        name = "(S) "~resolver.generateName(cast(Container)dnodegen.root.getEntity(), cast(Entity)entity);
    }
}

public class VariableAssignmentNode : DNode
{
    private VariableAssignment variableAssignment;

    this(DNodeGenerator dnodegen, VariableAssignment variableAssignment)
    {
        super(dnodegen, variableAssignment);

        this.variableAssignment = variableAssignment;

        initName();
    }

    private void initName()
    {
        /* get the associated variable */
        Variable associatedVariable = variableAssignment.getVariable();

        name = resolver.generateName(cast(Container)dnodegen.root.getEntity(), associatedVariable)~" (assignment)";
    }
}