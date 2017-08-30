package org.eclipse.viatra.dslreasoner.patternmutator

import org.eclipse.viatra.dslreasoner.mutatedpatterns.Pattern
import org.eclipse.viatra.examples.cps.cyberPhysicalSystem.CyberPhysicalSystemPackage
import java.util.HashSet

class Run {
	 def static void main(String[] args) {
	 	val String import = CyberPhysicalSystemPackage.eINSTANCE.nsURI.toString  
	 	val HashSet<String> imports = new HashSet<String> 
		imports.add(import)
		
        val String outputFolder = "src/org/eclipse/viatra/dslreasoner/mutatedpatterns/"
		val String package = "mutatedpatterns"	

		val p = Pattern.instance	
		val PatternMutator mutator = new PatternMutator()
     	mutator.mutate(p.specifications.toList, package, imports, outputFolder)  
	 }
}