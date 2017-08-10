package org.eclipse.viatra.dslreasoner.patternmutator

import com.google.common.collect.Sets
import java.io.File
import java.util.Collection
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.viatra.query.runtime.api.AdvancedViatraQueryEngine
import org.eclipse.viatra.query.runtime.api.IPatternMatch
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.api.ViatraQueryMatcher
import org.eclipse.viatra.query.runtime.emf.EMFScope
import org.junit.AfterClass
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameter
import org.junit.runners.Parameterized.Parameters
import org.eclipse.emf.common.util.URI

class TempTest {
	
    @Test
    def void tempTest() {

        val p = hu.bme.mit.inf.dslreasoner.domains.transima.fam.patterns.Pattern.instance
        val PatternTransformer pt = new PatternTransformer(p.specifications.toList)
        pt.transformPatterns()
   
    }
}
