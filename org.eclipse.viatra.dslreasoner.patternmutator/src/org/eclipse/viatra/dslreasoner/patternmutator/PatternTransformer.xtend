package org.eclipse.viatra.dslreasoner.patternmutator

import java.util.ArrayList
import java.util.HashMap
import java.util.LinkedList
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EAttribute
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EEnum
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.EcorePackage
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.emf.EMFQueryMetaContext
import org.eclipse.viatra.query.runtime.emf.types.BaseEMFTypeKey
import org.eclipse.viatra.query.runtime.emf.types.EClassTransitiveInstancesKey
import org.eclipse.viatra.query.runtime.emf.types.EDataTypeInSlotsKey
import org.eclipse.viatra.query.runtime.matchers.context.IQueryMetaContext
import org.eclipse.viatra.query.runtime.matchers.psystem.PBody
import org.eclipse.viatra.query.runtime.matchers.psystem.PConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.PVariable
import org.eclipse.viatra.query.runtime.matchers.psystem.annotations.ParameterReference
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.NegativePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PParameter
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.rewriters.PBodyNormalizer
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.TypeConstraint
import org.eclipse.viatra.query.runtime.matchers.context.IInputKey
import org.eclipse.viatra.query.runtime.matchers.psystem.KeyedEnumerablePConstraint
import org.eclipse.viatra.query.runtime.matchers.context.common.BaseInputKeyWrapper
import org.eclipse.viatra.query.runtime.emf.types.EStructuralFeatureInstancesKey
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.PositivePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.EnumerablePConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.DeferredPConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Equality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Inequality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.ConstantValue

class PatternTransformer {
	var List<? extends IQuerySpecification<?>> patterns
	var List<? extends IQuerySpecification<?>> transformedPatterns

	new(List<? extends IQuerySpecification<?>> patterns) {
		this.patterns = patterns
	}

	private def String filterParamWildCards (String parameter){ 
		if(parameter.matches("_<[0-9]+>")){
			return "_"
		}			
		return parameter
	}
	public def transformPatterns() {
		var filteredPattern = patterns.filter[it.allAnnotations.exists[it.name == "Constraint"]].toSet
		for (pattern : patterns) {
			var boolean isQueryBasedFeature = false
			for (annotation : pattern.allAnnotations) {
				if(annotation.name == "QueryBasedFeature")
					isQueryBasedFeature = true
			}
			if(!isQueryBasedFeature){
				var int cntr = 0
				var pquery = pattern.internalQueryRepresentation
				//TODO explain why it is okay to normalize
				var normalizedPquery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(pquery)	
				var params = pquery.parameters
//				var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»(«FOR value : annotation.allValues SEPARATOR ', '»«IF value.key == "message" || value.key == "severity"»«value.key» = "«value.value»"«ENDIF»«IF value.key == "key"»«value.key» = «value.value»«ENDIF»«ENDFOR»)«ENDFOR»'''
//				var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»«ENDFOR»'''	
				var patternName = pquery.fullyQualifiedName.split("\\.").last
				var patternParams ='''(«FOR param : params SEPARATOR ', '»«param.name»: «param.typeName.split("\\.").last»«ENDFOR»)'''
				var String rebuiltQuery = ""
				
//				rebuiltQuery += 
//				'''
//	«««			«patternAnnotation»«»
//				pattern «patternName»V«cntr»«patternParams» {				
//				«FOR body : normalizedPquery.bodies SEPARATOR ' or {'»				
//					«FOR constraint : body.constraints»
//	«««				«constraint.class»
//	«««				TypeConstraint with EClassTransitiveInstancesKey:
//					«IF constraint.class ==  TypeConstraint»
//					«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
//					«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
//					«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«filterParamWildCards(param.toString)»);
//					«ENDFOR»
//					«ENDIF»
//	«««				TypeConstraint with EStructuralFeatureInstancesKey:
//					«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
//					«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
//					((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
//					FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);		
//					«ENDIF»
//					«ENDIF»
//	«««				PositivePatternCall:
//					«IF constraint.class == PositivePatternCall»
//					find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»V«cntr»(«
//					FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//					«ENDIF»
//	«««				NegativePatternCall:
//					«IF constraint.class == NegativePatternCall»
//					neg find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»V«cntr»(«
//					FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//					«ENDIF»
//	«««				ConstantValue:
//	«««             TODO: check if supplier is enum before casting...
//					«IF constraint.class == ConstantValue»
//					«(constraint as ConstantValue).variablesTuple.get(0)» == «
//					(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
//					(constraint as ConstantValue).supplierKey»;
//					«ENDIF»
//	«««				Equality:
//					«IF constraint.class == Equality»
//					«(constraint as Equality).who» == «(constraint as Equality).withWhom»;
//					«ENDIF»
//	«««				Inequality:
//					«IF constraint.class == Inequality»
//					«(constraint as Inequality).who» != «(constraint as Inequality).withWhom»;
//					«ENDIF»
//					«ENDFOR»
//				}
//				«ENDFOR»
//				
//				'''
				
			//	for (outsideParam : params) {
					for (outsideBody : normalizedPquery.bodies) {
						for (outsideConstraint : outsideBody.constraints) {
							if(outsideConstraint.class == PositivePatternCall || 
							   outsideConstraint.class == NegativePatternCall || 
							   outsideConstraint.class  == Equality ||
							   outsideConstraint.class == Inequality ||
							   outsideConstraint.class == ConstantValue
							) {
								rebuiltQuery +=  
								'''
«««								«patternAnnotation»«»
								pattern «patternName»V«cntr»«patternParams» {				
								«FOR body : normalizedPquery.bodies SEPARATOR ' or {'»				
									«FOR constraint : body.constraints»
«««									«constraint.class»
«««									TypeConstraint with EClassTransitiveInstancesKey:
									«IF constraint.class ==  TypeConstraint»
									«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
									«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
									«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«filterParamWildCards(param.toString)»);
									«ENDFOR»									
									«ENDIF»
«««									TypeConstraint with EStructuralFeatureInstancesKey:
									«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
									«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
									((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
									FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);		
									«ENDIF»
									«ENDIF»
«««									PositivePatternCall:
									«IF constraint.class == PositivePatternCall»
									«IF outsideConstraint != constraint»
									find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
									FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
									«ENDIF»
									«IF outsideConstraint == constraint»
									neg find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
									FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);
									«ENDIF»
									«ENDIF»
«««									NegativePatternCall:
									«IF constraint.class == NegativePatternCall»
									«IF outsideConstraint != constraint»
									neg find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
									FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
									«ENDIF»
									«IF outsideConstraint == constraint»
									find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
									FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
									«ENDIF»
									«ENDIF»
«««									ConstantValue:
«««					            	TODO: check if supplier is enum before casting...
									«IF constraint.class == ConstantValue»
									«IF outsideConstraint != constraint»
									«(constraint as ConstantValue).variablesTuple.get(0)» == «
									(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
									(constraint as ConstantValue).supplierKey»;
									«ENDIF»
									«IF outsideConstraint == constraint»
									«(constraint as ConstantValue).variablesTuple.get(0)» != «
									(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
									(constraint as ConstantValue).supplierKey»;
									«ENDIF»
									«ENDIF»
«««									Equality:
									«IF constraint.class == Equality»
									«IF outsideConstraint != constraint»
									«(constraint as Equality).who» == «(constraint as Equality).withWhom»;
									«ENDIF»
									«IF outsideConstraint == constraint»«(constraint as Equality).who» != «(constraint as Equality).withWhom»;
									«ENDIF»
									«ENDIF»
«««									Inequality:
									«IF constraint.class == Inequality»
									«IF outsideConstraint != constraint»
									«(constraint as Inequality).who» != «(constraint as Inequality).withWhom»;
									«ENDIF»
									«IF outsideConstraint == constraint»
									«(constraint as Inequality).who» == «(constraint as Inequality).withWhom»;
									«ENDIF»
									«ENDIF»
									«ENDFOR»
								}
								«ENDFOR»
								
								'''
								cntr++		
								
							}
						}
					}
				//}
				println(rebuiltQuery)
		
				}
			}
		}
	}
	