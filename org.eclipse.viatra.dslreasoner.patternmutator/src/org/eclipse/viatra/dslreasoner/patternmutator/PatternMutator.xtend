package org.eclipse.viatra.dslreasoner.patternmutator

import com.google.common.collect.Iterables
import com.google.common.collect.Sets
import java.util.ArrayList
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
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
import org.eclipse.viatra.query.patternlanguage.emf.specification.GenericEMFPatternPQuery
import org.eclipse.viatra.query.patternlanguage.emf.specification.GenericQuerySpecification
import org.eclipse.viatra.query.patternlanguage.emf.specification.SpecificationBuilder
import org.eclipse.viatra.query.patternlanguage.patternLanguage.Annotation
import org.eclipse.viatra.query.patternlanguage.patternLanguage.Modifiers
import org.eclipse.viatra.query.patternlanguage.patternLanguage.Pattern
import org.eclipse.viatra.query.patternlanguage.patternLanguage.PatternBody
import org.eclipse.viatra.query.patternlanguage.patternLanguage.PatternLanguagePackage
import org.eclipse.viatra.query.patternlanguage.patternLanguage.Variable
import org.eclipse.viatra.query.patternlanguage.patternLanguage.impl.AnnotationImpl
import org.eclipse.viatra.query.patternlanguage.patternLanguage.impl.PatternImpl
import org.eclipse.viatra.query.patternlanguage.patternLanguage.impl.PatternLanguageFactoryImpl
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.api.impl.BaseGeneratedEMFPQuery
import org.eclipse.viatra.query.runtime.emf.EMFQueryMetaContext
import org.eclipse.viatra.query.runtime.emf.types.BaseEMFTypeKey
import org.eclipse.viatra.query.runtime.emf.types.EClassTransitiveInstancesKey
import org.eclipse.viatra.query.runtime.emf.types.EDataTypeInSlotsKey
import org.eclipse.viatra.query.runtime.emf.types.EStructuralFeatureInstancesKey
import org.eclipse.viatra.query.runtime.matchers.context.IInputKey
import org.eclipse.viatra.query.runtime.matchers.context.IQueryMetaContext
import org.eclipse.viatra.query.runtime.matchers.context.common.BaseInputKeyWrapper
import org.eclipse.viatra.query.runtime.matchers.psystem.DeferredPConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.EnumerablePConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.KeyedEnumerablePConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.PBody
import org.eclipse.viatra.query.runtime.matchers.psystem.PConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.PVariable
import org.eclipse.viatra.query.runtime.matchers.psystem.annotations.ParameterReference
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Equality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Inequality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.NegativePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.ConstantValue
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.PositivePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.TypeConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.BasePQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PParameter
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.QueryInitializationException
import org.eclipse.viatra.query.runtime.matchers.psystem.rewriters.PBodyNormalizer
import org.eclipse.viatra.query.runtime.matchers.tuple.FlatTuple1
import org.eclipse.viatra.query.runtime.matchers.tuple.Tuple
import org.eclipse.viatra.query.runtime.matchers.tuple.Tuples
import org.eclipse.xtend.lib.annotations.Data
import com.google.common.collect.Lists
import org.eclipse.viatra.query.runtime.matchers.psystem.InitializablePQuery
import com.google.common.base.Preconditions
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery.PQueryStatus
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PProblem
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery.PQueryStatus
import org.eclipse.viatra.query.runtime.matchers.psystem.annotations.PAnnotation
import java.util.Arrays
import org.eclipse.viatra.query.runtime.exception.ViatraQueryException
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.ExportedParameter
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EEnumLiteral
import org.eclipse.emf.ecore.ETypedElement
import org.eclipse.emf.ecore.ENamedElement
import org.eclipse.viatra.query.runtime.matchers.tuple.FlatTuple
import org.eclipse.viatra.dslreasoner.patternmutator.util.FunctionalOutputQuerySpecification
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PDisjunction
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery.PQueryStatus

//import hu.bme.mit.inf.dslreasoner.domains.transima.fam.patterns.Pattern
//import org.eclipse.viatra.query.patternlanguage.patternLanguage.Pattern
public final class PatternMutator {
	
	private new() {}

	static class HelperPQuery extends BasePQuery implements InitializablePQuery {

		var String name = "NoName"
		//var PAnnotation annotation
		var List<PParameter> parameters = Lists.newArrayList()
		public var Set<PBody> bodies = Sets.newLinkedHashSet()

		new(PQuery queryToCopy) {
			copyPQuery(queryToCopy)
			initializeBodies(bodies)
		}

		static public def String filterParamWildCards(String parameter) {
			if (parameter.matches("_<[0-9]+>")) {
				return "_"
			}
			return parameter
		}

		def EClassifier getClassifierLiteral(String packageUri,
			String classifierName) throws QueryInitializationException {
			var EPackage ePackage = EPackage.Registry.INSTANCE.getEPackage(packageUri);
			if (ePackage == null)
				throw new QueryInitializationException("Query refers to EPackage {1} not found in EPackage Registry.",
					#{packageUri}, "Query refers to missing EPackage.", this);
			var EClassifier literal = ePackage.getEClassifier(classifierName);
			if (literal == null)
				throw new QueryInitializationException("Query refers to classifier {1} not found in EPackage {2}.",
					#{classifierName, packageUri}, "Query refers to missing type in EPackage.", this);
			return literal;
		}
		
		def EStructuralFeature getFeatureLiteral(String packageUri, String className, String featureName) throws QueryInitializationException {
	       var EClassifier container = getClassifierLiteral(packageUri, className);
	        if (! (container instanceof EClass)) 
	            throw new QueryInitializationException(
	                    "Query refers to EClass {1} in EPackage {2} which turned out not be an EClass.", 
	                    #{className, packageUri}, 
	                    "Query refers to missing EClass.", this);
	        var EStructuralFeature feature = (container as EClass).getEStructuralFeature(featureName);
	        if (feature == null) 
	            throw new QueryInitializationException(
	                    "Query refers to feature {1} not found in EClass {2}.", 
	                    #{featureName, className}, 
	                    "Query refers to missing feature.", this);
	        return feature;
	    }

	    def protected EEnumLiteral getEnumLiteral(String packageUri, String enumName, String literalName) throws QueryInitializationException {
	        var EClassifier enumContainer = getClassifierLiteral(packageUri, enumName);
	        if (! (enumContainer instanceof EEnum)) 
	            throw new QueryInitializationException(
	                    "Query refers to EEnum {1} in EPackage {2} which turned out not be an EEnum.", 
	                    #{enumName, packageUri}, 
	                    "Query refers to missing enumeration type.", this);
	        var EEnumLiteral literal = (enumContainer as EEnum).getEEnumLiteral(literalName);
	        if (literal == null) 
	            throw new QueryInitializationException(
	                    "Query refers to enumeration literal {1} not found in EEnum {2}.", 
	                    #{literalName, enumName}, 
	                    "Query refers to missing enumeration literal.", this);
	        return literal;
	    }
		
		def copyBody(PBody bodyToCopy) throws QueryInitializationException{
			try {
				
				if(!bodies.contains(bodyToCopy)){				
					var PBody body = new PBody(this)
					bodies.add(body)
					//TODO setSymbolicParameters...
					for (constraint : bodyToCopy.constraints) {
						
						// TypeConstraint
						if (constraint.class == TypeConstraint) {
							if((constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey){								
								var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(
								(constraint as TypeConstraint).variablesTuple.elements.get(0).toString))
								new TypeConstraint(body, Tuples.flatTupleOf(variable),
									new EClassTransitiveInstancesKey(((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).emfKey)) 
							}				
							else if((constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey){
								var List<PVariable> variables = newArrayList
								for (readVariable : (constraint as TypeConstraint).variablesTuple.elements) {
									var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
									variables.add(variable)
								}						
								var String packageUriName =  ((((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey as ETypedElement).EType.EPackage.nsURI.toString)					
								var String className = ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last
								var String featureName = ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name
								new TypeConstraint(body, Tuples.flatTupleOf(variables.toArray), new EStructuralFeatureInstancesKey(
											getFeatureLiteral(packageUriName, className, featureName)))	
							}					
							    
						}
						
						// PositivePatternCall
						if (constraint.class == PositivePatternCall) {
								var List<PVariable> variables = newArrayList
								for (readVariable : (constraint as PositivePatternCall).variablesTuple.elements) {
									var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
									variables.add(variable)
								}				
					            new PositivePatternCall(body, new FlatTuple(variables.toArray), (constraint as PositivePatternCall).referredQuery);
						}
						
						// NegativePatternCall
						if (constraint.class == NegativePatternCall) {
								var List<PVariable> variables = newArrayList
								for (readVariable : (constraint as NegativePatternCall).actualParametersTuple.elements) {
									var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
									variables.add(variable)
								}				
					            new NegativePatternCall(body, new FlatTuple(variables.toArray), (constraint as NegativePatternCall).referredQuery);
						}
						
						// ConstantValue
						if (constraint.class == ConstantValue) {
//			            	TODO: check if supplier is enum before casting...
							var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(
								(constraint as ConstantValue).variablesTuple.get(0) .toString))
							new ConstantValue(body, variable, (constraint as ConstantValue).supplierKey)									
						}
						
						// Equality
						if (constraint.class == Equality) {
							var PVariable who = body.getOrCreateVariableByName((constraint as Equality).who.toString)
							var PVariable withWhom = body.getOrCreateVariableByName((constraint as Equality).withWhom.toString)
							new Equality(body, who, withWhom)
						}
						
						// Inequality
						if (constraint.class == Inequality) {
							var PVariable who = body.getOrCreateVariableByName((constraint as Inequality).who.toString)
							var PVariable withWhom = body.getOrCreateVariableByName((constraint as Inequality).withWhom.toString)
							new Inequality(body, who, withWhom)
						}						
					}//ENDFOR					
				}//ENDIF
					
			// to silence compiler error
			if(false) throw new ViatraQueryException("Never", "happens");
			} catch (ViatraQueryException ex) {
					throw (ex);
			}
		}
			
		def copyPQuery(PQuery queryToCopy) throws QueryInitializationException{
			try {
				
				// Copy Annotations: TODO
				for (annotation : queryToCopy.allAnnotations) {
//					var PAnnotation an = new PAnnotation(annotation.name)
////					for (attribute : annotation.allValues) {
////						an.addAttribute(attribute.key.toString, (attribute.value as Object[]).clone)
////						
////					}
//					this.addAnnotation(an)

				}

				//Copy Name:
				this.name = queryToCopy.fullyQualifiedName.toString
				
				//Copy Parameters:
				for (parameter : queryToCopy.parameters) {
					var PParameter p = new PParameter(parameter.name, parameter.typeName, parameter.declaredUnaryType, parameter.direction)
					addParameter(p)
				}
				
				// Copy Bodies:				
				for (body : queryToCopy.disjunctBodies.bodies) {
					copyBody(body)	
				}
				
			// to silence compiler error
			if(false) throw new ViatraQueryException("Never", "happens");
			} catch (ViatraQueryException ex) {
				throw (ex);
			}
		}
		
//			def createBody() throws QueryInitializationException{
//				try { // TODO
//					var PBody body = new PBody(this);
//					// to silence compiler error
//					if(false) throw new ViatraQueryException("Never", "happens");
//				} catch (ViatraQueryException ex) {
//					throw (ex);
//				}
//			}

		def void addParameter(PParameter parameter) {
			this.parameters.add(parameter)
		}
		
		override void addAnnotation(PAnnotation annotation) {
			// Making the upper-level construct visible
			super.addAnnotation(annotation);
		}

		override protected doGetContainedBodies() {
			return bodies
		}

		override getFullyQualifiedName() {
			return name
		}

		override getParameters() {
			return parameters
		}

		override initializeBodies(Set<PBody> bodies) throws QueryInitializationException {
		    super.bodies = bodies
		}

		override setStatus(PQueryStatus newStatus) {
			Preconditions.checkState(isMutable(),
				"The status of the specification can only be set for uninitialized queries.");
			super.setStatus(newStatus);
		}

		override void addError(PProblem problem) {
			Preconditions.checkState(isMutable() || getStatus().equals(PQueryStatus.ERROR),
				"Errors can only be added to unitialized or erroneous queries.");
			super.addError(problem);
		}
		
	}
	
	static public def String filterParamWildCards(String parameter) {
		if (parameter.matches("_<[0-9]+>")) {
			return "_"
		}
		return parameter
	}
	
	static public def String getTextualRepresentationOfPQuery(PQuery pquery){		
		//TODO explain why it is okay to normalize
		var normalizedPquery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(pquery)	
		var params = pquery.parameters
//		var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»(«FOR value : annotation.allValues SEPARATOR ', '»«IF value.key == "message" || value.key == "severity"»«value.key» = "«value.value»"«ENDIF»«IF value.key == "key"»«value.key» = «value.value»«ENDIF»«ENDFOR»)«ENDFOR»'''
//		var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»«ENDFOR»'''	
		var patternName = pquery.fullyQualifiedName.split("\\.").last
		var patternParams ='''(«FOR param : params SEPARATOR ', '»«param.name»: «param.typeName.split("\\.").last»«ENDFOR»)'''				
		var String text = ""				
		text +=	'''
«««		«patternAnnotation»«»
		pattern «patternName»«patternParams» {				
		«FOR body : normalizedPquery.bodies SEPARATOR ' or {'»				
			«FOR constraint : body.constraints»
«««			«constraint.class»
«««			TypeConstraint with EClassTransitiveInstancesKey:
			«IF constraint.class ==  TypeConstraint»
			«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
			«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
			«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«filterParamWildCards(param.toString)»);
			«ENDFOR»
			«ENDIF»
«««			TypeConstraint with EStructuralFeatureInstancesKey:
			«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
			«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
			((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
			FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);		
			«ENDIF»
			«ENDIF»
«««			PositivePatternCall:
			«IF constraint.class == PositivePatternCall»
			find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
			FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
			«ENDIF»
«««			NegativePatternCall:
			«IF constraint.class == NegativePatternCall»
			neg find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
			FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
			«ENDIF»
«««			ConstantValue:
«««         TODO: check if supplier is enum before casting...
			«IF constraint.class == ConstantValue»
			«(constraint as ConstantValue).variablesTuple.get(0)» == «
			(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
			(constraint as ConstantValue).supplierKey»;
			«ENDIF»
«««			Equality:
			«IF constraint.class == Equality»
			«(constraint as Equality).who» == «(constraint as Equality).withWhom»;
			«ENDIF»
«««			Inequality:
			«IF constraint.class == Inequality»
			«(constraint as Inequality).who» != «(constraint as Inequality).withWhom»;
			«ENDIF»
			«ENDFOR»
		}
		«ENDFOR»	
		'''
		return text
	}
	
	static def mutate(List<? extends IQuerySpecification<?>> querySpecifications) {
		
		var specifications = new ArrayList<IQuerySpecification<?>>
		var pQueries = new HashSet<PQuery>
		var HashSet<PQuery> workingSetQueries = new HashSet<PQuery>
		var HashMap<String, PQuery> mutatedQueries = new HashMap<String, PQuery>
		
		for (IQuerySpecification<?> specification : querySpecifications) {
			specifications.add(specification);
		}
		
		for (spec : specifications) {
			pQueries.add(spec.internalQueryRepresentation)
		}
					
		for (query : pQueries) {
			var PatternMutator.HelperPQuery p = new HelperPQuery(query)
			workingSetQueries.add(p)
		}
		
		for (pquery : workingSetQueries) {
			println(getTextualRepresentationOfPQuery(pquery))
		}
					
		for (pquery : pQueries) {
			
		}
//				for (outsideParam : pquery.parameters) {
//					var String name = outsideParam.typeName.split("\\.").last
//					var boolean notContained = true;
//					for (element : alreadyOutsourcedParam) {
//						if (name.equals(element)) {
//							notContained = false	
//						}												
//					}
//					if (notContained) {						
//						//if we haven't outsourced the parameter yet 
//						alreadyOutsourcedParam.add(name)
//						rebuiltQuery +=  '''
//						pattern «name»(var){
//							«name»(var)
//						}
//						
//						'''
//						//check if parameter already included in a constraint, if not then add
//						var boolean alreadyAdded = false
//						for (body :  normalizedPquery.bodies) {
//							for (const : body.constraints) {
//								if (const.class == TypeConstraint && (const as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey
//									&& ((const as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name == name
//								) {
//									println("already added ")
//									alreadyAdded = true
//								} 
//
//«««						«patternAnnotation»«»
//							pattern «patternName»V«cntr»«patternParams» {				
//							«FOR body : normalizedPquery.bodies SEPARATOR ' or {'»				
//								«FOR constraint : body.constraints»
//«««									«constraint.class»
//«««									TypeConstraint with EClassTransitiveInstancesKey:
//								«IF constraint.class ==  TypeConstraint»
//								«IF constraint  != outsideConstraint»
//								«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
//								«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
//								«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«filterParamWildCards(param.toString)»);
//								«ENDFOR»	
//								«ENDIF»															
//								«IF constraint  == outsideConstraint»
//								«ENDIF»
//								«ENDIF»
//«««									TypeConstraint with EStructuralFeatureInstancesKey:
//								«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
//								«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
//								((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
//								FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);		
//								«ENDIF»
//								«ENDIF»
//«««									PositivePatternCall:
//								«IF constraint.class == PositivePatternCall»
//								«IF outsideConstraint != constraint»
//								find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//								«ENDIF»
//								«IF outsideConstraint == constraint»
//								neg find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);
//								«ENDIF»
//								«ENDIF»
//«««									NegativePatternCall:
//								«IF constraint.class == NegativePatternCall»
//								«IF outsideConstraint != constraint»
//								neg find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//								«ENDIF»
//								«IF outsideConstraint == constraint»
//								find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//								«ENDIF»
//								«ENDIF»
//«««									ConstantValue:
//«««					            	TODO: check if supplier is enum before casting...
//								«IF constraint.class == ConstantValue»
//								«IF outsideConstraint != constraint»
//								«(constraint as ConstantValue).variablesTuple.get(0)» == «
//								(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
//								(constraint as ConstantValue).supplierKey»;
//								«ENDIF»									
//								«IF outsideConstraint == constraint»
//								«(constraint as ConstantValue).variablesTuple.get(0)» != «
//								(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
//								(constraint as ConstantValue).supplierKey»;
//								«ENDIF»
//								«ENDIF»
//«««									Equality:
//								«IF constraint.class == Equality»
//								«IF outsideConstraint != constraint»
//								«(constraint as Equality).who» == «(constraint as Equality).withWhom»;
//								«ENDIF»
//								«IF outsideConstraint == constraint»«(constraint as Equality).who» != «(constraint as Equality).withWhom»;
//								«ENDIF»
//								«ENDIF»
//«««									Inequality:
//								«IF constraint.class == Inequality»
//								«IF outsideConstraint != constraint»
//								«(constraint as Inequality).who» != «(constraint as Inequality).withWhom»;
//								«ENDIF»
//								«IF outsideConstraint == constraint»
//								«(constraint as Inequality).who» == «(constraint as Inequality).withWhom»;
//								«ENDIF»
//								«ENDIF»
//								«ENDFOR»
//							}
//							«ENDFOR»
//							
//							'''					


	}

}

	