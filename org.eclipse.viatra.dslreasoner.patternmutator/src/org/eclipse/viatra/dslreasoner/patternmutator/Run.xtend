package org.eclipse.viatra.dslreasoner.patternmutator

import org.eclipse.viatra.dslreasoner.mutatedpatterns.Pattern
import org.eclipse.viatra.examples.cps.cyberPhysicalSystem.CyberPhysicalSystemPackage

class Run {
	 def static void main(String[] args) {
	 	CyberPhysicalSystemPackage.eINSTANCE.nsURI 
	 	val p = Pattern.instance
        val PatternMutator mutator = new PatternMutator()
              
        val String outputFolder = "src/org/eclipse/viatra/dslreasoner/mutatedpatterns/"
		val String packageOfVqls=
		'''
		package mutatedpatterns
		
		'''
		val String importsInVqls = 
		'''
		import "http://org.eclipse.viatra/model/cps"
		
		'''
     	mutator.mutate(p.specifications.toList, packageOfVqls, importsInVqls, outputFolder)  
	 }
}