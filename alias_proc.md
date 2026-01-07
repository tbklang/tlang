Steps
=====

1. Start at some container c_1
2. Discover all `VariableExpression`(s) call these v
3. For every `v_i` in `v` (with [`v_i`,`c_1`] as args); call this proc(v_i, c_1)
	i. Does it's `getName()` refer to a near alias declaration? (a_i)
	i. If not; return
4. If `getName()` DOES refer to an alias declaration, then:
	i. Get a_i expression: e_i
	 i. `c_1.replace(v_i, proc(e_i))`

This is a rough idea, it still needs some visitation mechanism. I have
an idea for that potentially. A "painting call" could be placed inside
of the predicate passed to the resolver.
