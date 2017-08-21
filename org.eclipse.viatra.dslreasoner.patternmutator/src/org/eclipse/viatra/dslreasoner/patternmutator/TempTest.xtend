package org.eclipse.viatra.dslreasoner.patternmutator

import hu.bme.mit.inf.dslreasoner.domains.transima.fam.patterns.Pattern
import org.junit.Test

class TempTest {
	
    @Test
    def void tempTest() {
        val p = Pattern.instance
        val PatternMutator mutator = new PatternMutator()
        mutator.mutate(p.specifications.toList)
   
    }
}
