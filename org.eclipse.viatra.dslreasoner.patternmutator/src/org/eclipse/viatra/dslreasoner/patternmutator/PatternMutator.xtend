package org.eclipse.viatra.dslreasoner.patternmutator

import com.google.common.base.Preconditions
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.util.ArrayList
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EEnum
import org.eclipse.emf.ecore.EEnumLiteral
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.emf.EMFQueryMetaContext
import org.eclipse.viatra.query.runtime.emf.types.EClassTransitiveInstancesKey
import org.eclipse.viatra.query.runtime.emf.types.EStructuralFeatureInstancesKey
import org.eclipse.viatra.query.runtime.exception.ViatraQueryException
import org.eclipse.viatra.query.runtime.matchers.context.IInputKey
import org.eclipse.viatra.query.runtime.matchers.context.common.JavaTransitiveInstancesKey
import org.eclipse.viatra.query.runtime.matchers.psystem.EnumerablePConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.InitializablePQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.PBody
import org.eclipse.viatra.query.runtime.matchers.psystem.PConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.PVariable
import org.eclipse.viatra.query.runtime.matchers.psystem.annotations.PAnnotation
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.AggregatorConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Equality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.ExportedParameter
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.ExpressionEvaluation
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Inequality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.NegativePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.PatternMatchCounter
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.TypeFilterConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.BinaryTransitiveClosure
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.ConstantValue
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.PositivePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.TypeConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.BasePQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PDisjunction
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PParameter
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PProblem
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.QueryInitializationException
import org.eclipse.viatra.query.runtime.matchers.psystem.rewriters.PBodyNormalizer
import org.eclipse.viatra.query.runtime.matchers.tuple.Tuple
import org.eclipse.viatra.query.runtime.matchers.tuple.Tuples

/**
 * <b>Usage:</b> Instantiate then use the mutate method for pattern mutations.
 */
public class PatternMutator {
	
	static protected var HashMap<String ,PQuery> outsourcedQueries = newHashMap
	
	/**
	 * Helper class which extends the BasePQuery. Adds copying and mutating abilities.
	 * Provides two constructors: One to copy a Query, and another one to Copy and negate one constraint contained by the original query.
	 */		
	static class HelperPQuery extends BasePQuery implements InitializablePQuery {

		var String name = "NoName"
		var int version = -1
		var List<PParameter> parameters = newArrayList()
		var Set<PBody> bodies = newLinkedHashSet()
	
		private new(){} // Added Bodies Must be initialized later!
		
		new(PQuery queryToCopy) {
			copyPQuery(queryToCopy, null)
			initializeBodies(bodies)
		}
		
		new(PQuery queryToCopy, int version, PConstraint constraintToNegate) {
			this.version = version
			copyPQuery(queryToCopy, constraintToNegate)

			initializeBodies(bodies)
		}

		static public def String filterParamWildCards(String parameter) {
			var String temp = parameter
			if (parameter.matches("_<[0-9]+>")) {
				temp = parameter.replaceAll("_", "")
				temp = temp.replaceAll("<", "")
				temp = temp.replaceAll(">", "")			
				temp = "aVariable" + temp 	
			}
			if (parameter.matches(".virtual\\{([0-9]+)\\}")) {
				temp = parameter.replaceAll("\\{", "")
				temp = temp.replaceAll("virtual", "enumVariable")
				temp = temp.replaceAll("\\}", "")
				temp = temp.replaceAll("\\.", "")
			}
			return temp	
		}
			
		def EClassifier getClassifierLiteral(String packageUri,
			String classifierName) throws QueryInitializationException {
			var EPackage ePackage = EPackage.Registry.INSTANCE.getEPackage(packageUri);
			if (ePackage === null)
				throw new QueryInitializationException("Query refers to EPackage {1} not found in EPackage Registry.",
					#{packageUri}, "Query refers to missing EPackage.", this);
			var EClassifier literal = ePackage.getEClassifier(classifierName);
			if (literal === null)
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
	        if (feature === null) 
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
	        if (literal === null) 
	            throw new QueryInitializationException(
	                    "Query refers to enumeration literal {1} not found in EEnum {2}.", 
	                    #{literalName, enumName}, 
	                    "Query refers to missing enumeration literal.", this);
	        return literal;
	    }
	    
	    def List<PVariable> copyAndCreateVars(PBody body, PConstraint constraint){
			var List<PVariable> variables = newArrayList
			switch (constraint.class) {
				case TypeConstraint: {			
					for (readVariable : (constraint as EnumerablePConstraint).variablesTuple.elements) {
						var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
						variables.add(variable)
					}	
					return variables
				}
				case PositivePatternCall: {			
					for (readVariable : (constraint as EnumerablePConstraint).variablesTuple.elements) {
						var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
						variables.add(variable)
					}	
					return variables
				}
				case EnumerablePConstraint: {			
					for (readVariable : (constraint as EnumerablePConstraint).variablesTuple.elements) {
						var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
						variables.add(variable)
					}	
					return variables
				}
				case NegativePatternCall: {			
					for (readVariable : (constraint as NegativePatternCall).actualParametersTuple.elements) {
						var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
						variables.add(variable)
					}
					return variables
				}
				case Equality: {
					var PVariable who = body.getOrCreateVariableByName((constraint as Equality).who.toString)
					var PVariable withWhom = body.getOrCreateVariableByName((constraint as Equality).withWhom.toString)
					variables.add(who)
					variables.add(withWhom)
					return variables
				}			
				case Inequality: {
					var PVariable who = body.getOrCreateVariableByName((constraint as Inequality).who.toString)
					var PVariable withWhom = body.getOrCreateVariableByName((constraint as Inequality).withWhom.toString)
					variables.add(who)
					variables.add(withWhom)
					return variables
				}		
				default: {
					return variables
				}
			}
		}
		def void createTypeConstraintsForVars(List<PVariable> variables, PBody body){
			for(variable : variables){
				new TypeConstraint(body, Tuples.flatTupleOf(variable),
					new EClassTransitiveInstancesKey(getClassifierLiteral("http://www.eclipse.org/emf/2002/Ecore", "EObject") as EClass))	
			}	
		} 	
			
		/**
		 * Copies the values of the given TypeConstraints and creates a new one from them. The created constraint gets added to the provided PBody. 
		 *  Used by {@link #copyBody(PBody, PConstraint) copyBody}.
		 *
		 */	    
	    def private void createTypeConstraintFrom(PBody body, List<PVariable> variables, TypeConstraint baseConstraint){
			if(baseConstraint.supplierKey.class == EClassTransitiveInstancesKey){								
				new TypeConstraint(body, Tuples.flatTupleOf(variables.get(0)),
					new EClassTransitiveInstancesKey((baseConstraint.supplierKey as EClassTransitiveInstancesKey).emfKey)) 
			}				
			else if(baseConstraint.supplierKey.class == EStructuralFeatureInstancesKey){									
				val wrappedKey = (baseConstraint.supplierKey as EStructuralFeatureInstancesKey).wrappedKey
				var String packageUriName =  wrappedKey.eContainer.eResource.URI.toString					
				var String className = wrappedKey.containerClass.typeName.split("\\.").last
				var String featureName = wrappedKey.name					
				new TypeConstraint(body, Tuples.flatTupleOf(variables.toArray), new EStructuralFeatureInstancesKey(
					getFeatureLiteral(packageUriName, className, featureName)))	
			}		
	    }
	    
		/**
		 * Copies the values of the given <b>TypeConstraints</b> and creates a <b>NegativePatternCall</b> based on the specified type. 
		 * The created constraint gets added to the provided PBody. A helper pattern must be created which is referenced by the <b>NegativePatternCall</b>.
		 * The helper pattern is a <b>HelperPQuery</b> which is added to the <b>HashMap</b>
		 * Used by {@link #copyBody(PBody, PConstraint) copyBody}.
		 *
		 */	  	    
		def private void negateTypeConstraint(PBody body, TypeConstraint baseConstraint, List<PVariable> variables, HashMap<String ,PQuery> outsourcedQueries){																				
			// Derive the name from the constraint
			val fqn = baseConstraint.PSystem.pattern.fullyQualifiedName
			var String outsourcedPatternName = fqn.substring(0, fqn.lastIndexOf(".") + 1)																	
			if(baseConstraint.supplierKey.class == EClassTransitiveInstancesKey)
				outsourcedPatternName = (baseConstraint.supplierKey as EClassTransitiveInstancesKey).emfKey.name
			else if(baseConstraint.supplierKey.class == EStructuralFeatureInstancesKey) {
				val wrappedKey = (baseConstraint.supplierKey as EStructuralFeatureInstancesKey).wrappedKey
				outsourcedPatternName += wrappedKey.containerClass.typeName.split("\\.").last + "_" + wrappedKey.name.toFirstUpper
			}			
			// Outsource and create pattern from typeconstraint	
			if(outsourcedPatternName !== null && !outsourcedQueries.containsKey(outsourcedPatternName)){	
				var List<PVariable> outsourcedVariables = newArrayList
				var HelperPQuery pq = new HelperPQuery()
				var PBody outsourcedBody = new PBody(pq) 
				pq.bodies.add(outsourcedBody)			
				for (readVariable : baseConstraint.variablesTuple.elements) {
						var PVariable variable = outsourcedBody.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
						outsourcedVariables.add(variable)
				}		

				//Different Key Types
				if(baseConstraint.supplierKey.class == EClassTransitiveInstancesKey){					
					for(variable : outsourcedVariables){
						var PParameter p = new PParameter(variable.name, ((baseConstraint.supplierKey as EClassTransitiveInstancesKey).emfKey).name)
						pq.addParameter(p)
					}											
					new TypeConstraint(outsourcedBody, Tuples.flatTupleOf(outsourcedVariables.get(0)),
						new EClassTransitiveInstancesKey((baseConstraint.supplierKey as EClassTransitiveInstancesKey).emfKey))
					
				}else if(baseConstraint.supplierKey.class == EStructuralFeatureInstancesKey){	
					for(variable : outsourcedVariables){
						var String typeName
						var IInputKey key
						//find the type name from the parameters
						for(param : baseConstraint.PSystem.pattern.parameters){
							if(param.name == variable.name && typeName === null && key === null){
								typeName = param.typeName 
								key = param.declaredUnaryType
							}							
						}				
						var PParameter p = new PParameter(variable.name, typeName, key)
						pq.addParameter(p)
					}		
					
					val wrappedKey = (baseConstraint.supplierKey as EStructuralFeatureInstancesKey).wrappedKey										
					var String packageUriName =  wrappedKey.eContainer.eResource.URI.toString		
					var String className = wrappedKey.containerClass.typeName.split("\\.").last
					var String featureName = wrappedKey.name
					new TypeConstraint(outsourcedBody, Tuples.flatTupleOf(outsourcedVariables.toArray), new EStructuralFeatureInstancesKey(
						getFeatureLiteral(packageUriName, className, featureName)))	
				}																				
				pq.name = outsourcedPatternName
				outsourcedQueries.put(pq.name, pq)																																									
				pq.initializeBodies(pq.bodies)
			}											
			//create negative pattern call on the outsourced pattern
			new NegativePatternCall(body, Tuples.flatTupleOf(variables.toArray), outsourcedQueries.get(outsourcedPatternName));	
			//remove Parameter Type for mutated queries
			var List<Integer> indexesOfParametersToMutate = newArrayList
            for (param : parameters) {            	          	            	
            	if(variables.exists[it.name == param.name]) {
            		indexesOfParametersToMutate.add(parameters.indexOf(param))
            	}
            }
	        for (index : indexesOfParametersToMutate) {
	        	var p = new PParameter(parameters.get(index).name, EObject.typeName)
	        	parameters.set(index, p)
	        }
		}

		/**
		 * Creates a new body for this pattern by copying the provided PBody. The passed PConstraint gets negated in the newly created body.
		 * Used by {@link #copyPQuery(PBody, PConstraint) copyPQuery}.
		 *
		 */		
		def private void copyBody(PBody bodyToCopy, PConstraint constraintToNegate) throws QueryInitializationException{
			try { if(bodies.contains(bodyToCopy)){ return }				
				//TODO setSymbolicParameters...																		
				// Create new Body		
				var PBody body = new PBody(this)
				bodies.add(body)				
				// Copy Constraints
				for (constraint : bodyToCopy.constraints) {	
					var List<PVariable> variables = copyAndCreateVars(body, constraint)		
					var boolean negate = (constraintToNegate !== null && constraint.toString == constraintToNegate.toString)			
					switch (constraint.class) {
						case TypeConstraint: {																			
							if (negate) { 										
								createTypeConstraintsForVars(variables, body)				
								negateTypeConstraint(body, constraintToNegate as TypeConstraint, variables, outsourcedQueries)									

							} else {
								createTypeConstraintFrom(body, variables, constraint as TypeConstraint)  
							}						
						}
						case PositivePatternCall: {
							var PQuery referredQuerry = (constraint as PositivePatternCall).referredQuery
							var Tuple vars = Tuples.flatTupleOf(variables.toArray)
							if (negate) { 
								createTypeConstraintsForVars(variables, body)		
								new NegativePatternCall(body, vars, referredQuerry);
							} else { 
					            new PositivePatternCall(body, vars, referredQuerry);
							}	
						}
						case NegativePatternCall: {
							var PQuery referredQuerry = (constraint as NegativePatternCall).referredQuery
							var Tuple vars = Tuples.flatTupleOf(variables.toArray)
							if (negate) { 
								new PositivePatternCall(body, vars, referredQuerry);
							} else {		
					            new NegativePatternCall(body, vars, referredQuerry);
							}								
						}
						case ConstantValue: {
							//TODO negate?
							//println((constraint as ConstantValue).supplierKey)
							if(!variables.empty){
								new ConstantValue(body, variables.get(0), (constraint as ConstantValue).supplierKey)	
							}else{
								//TODO
							}
														
						}
						case Equality: {
							if (negate) {
								createTypeConstraintsForVars(variables, body)		
								new Inequality(body, variables.get(0), variables.get(1))	
							} else {	
						    	new Equality(body, variables.get(0), variables.get(1))
							}						
						}
						case Inequality: {
							if (negate) { 
								new Equality(body, variables.get(0), variables.get(1))	
							} else {
						    	new Inequality(body, variables.get(0), variables.get(1))
							}
						}
						default: {
							//throw new ViatraQueryException(constraint.class.typeName + " Constraint is not Supported", "Constraint is not Supported");
						}
					}			
				}//ENDFOR										
			} catch (ViatraQueryException ex) {
					throw (ex);
			}
		}

		/**
		 * Builds this <b>HelperPQuery</b> by copying the values of the provided <b>PQuery</b>
		 * The passed PConstraint gets negated. See {@link copyBody(PBody, PConstraint) copyBody}.
		 * Throws a QueryInitializationException if called after this HelperPQuery has been initialized.
		 * Used by the <b>constructors</b>.
		 *
		 */					
		def private copyPQuery(PQuery queryToCopy, PConstraint constraintToNegate) throws QueryInitializationException{
			try {			
//				for (annotation : queryToCopy.allAnnotations) {
//					//TODO
//				}
				//Copy Name:
				this.name = queryToCopy.fullyQualifiedName.toString				
				//Copy Parameters:
				for (parameter : queryToCopy.parameters) {
					var PParameter p = new PParameter(parameter.name, parameter.typeName, parameter.declaredUnaryType/* , /*parameter.direction*/)
					addParameter(p)
				}				
				// Copy Bodies:	
				var normalizedPquery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(queryToCopy)				
				for (body : normalizedPquery.bodies) {
					copyBody(body, constraintToNegate)	
				}				
			} catch (ViatraQueryException ex) {
				throw (ex);
			}
		}		
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
			if (version >= 0) {
				return name + "V" + version
			} else {
				return name
			}			 
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
	
	
	/**
	 * Returns the textual representation of a provided PQuery. The returned string is formatted as a .vql pattern.
	 * <p>
	 * <b>Unsupported constraint types:</b>
	 * ConstantValue, AggregatorConstraint, ExpressionEvaluation, ExportedParameter, PatternMatchCounter, TypeFilterConstraint, BinaryTransitiveClosure
	 *
	 * <p>
	 * <b>Supported key types for TypeConstraint:</b>
	 * EStructuralFeatureInstancesKey, EClassTransitiveInstancesKey
	 * 
	 * @param pquery
	 * @param normalized
	 */
	static private def String getTextualRepresentationOfPQuery(PQuery pquery, boolean normalized){		
		//TODO explain why it is okay to normalize
		var PDisjunction disjunction 
		if (normalized) {
			disjunction = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(pquery)
		} else {
			disjunction = pquery.disjunctBodies
		}
		var params = pquery.parameters
		//TODO annotations
//		var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»(«FOR value : annotation.allValues SEPARATOR ', '»«IF value.key == "message" || value.key == "severity"»«value.key» = "«value.value»"«ENDIF»«IF value.key == "key"»«value.key» = «value.value»«ENDIF»«ENDFOR»)«ENDFOR»'''
//		var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»«ENDFOR»'''	
		var patternName = pquery.fullyQualifiedName.split("\\.").last
		
		var patternParams ='''(«FOR param : params SEPARATOR ', '»«param.name»«IF param.typeName !== null»: «
		IF param.declaredUnaryType !== null && param.declaredUnaryType.class == JavaTransitiveInstancesKey»java «ENDIF»«
		param.typeName.split("\\.").last»«ENDIF»«ENDFOR»)'''		
		var String text = ""				
		text +=	'''
«««		«patternAnnotation»«»
		pattern «patternName»«patternParams» {				
		«FOR body : disjunction.bodies SEPARATOR ' or {'»				
			«FOR constraint : body.constraints»
«««			«constraint.class»
			«IF constraint.class ==  TypeConstraint»
«««			TypeConstraint with EClassTransitiveInstancesKey:
			«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
			«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
			«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«
			HelperPQuery.filterParamWildCards(param.toString)»);
			«ENDFOR»
			«ENDIF»
«««			TypeConstraint with EStructuralFeatureInstancesKey:
			«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
			«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
			((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
			FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '
			»«HelperPQuery.filterParamWildCards(param.toString)»«ENDFOR»);		
			«ENDIF»
			«ENDIF»
«««			PositivePatternCall:
			«IF constraint.class == PositivePatternCall»
			find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
			FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«
			HelperPQuery.filterParamWildCards(param.toString)»«ENDFOR»);	
			«ENDIF»
«««			NegativePatternCall:
			«IF constraint.class == NegativePatternCall»
			neg find «IF (constraint as NegativePatternCall).referredQuery !== null
			»«(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»«ENDIF»(«
			FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«
			IF param !== null»«HelperPQuery.filterParamWildCards(param.toString)»«ENDIF»«ENDFOR»);	
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
	
	/**
	 * Creates an outsourcedQueries.vql, which contains all the patterns needed for negative calls.
	 * Also creates a standalone .vql file for each mutated pattern.
	 * <p>
	 * Automatically adds the import of Ecore to the provided imports. 
	 * <p>
	 * <b>Unsupported constraint types:</b>
	 * ConstantValue, AggregatorConstraint, ExpressionEvaluation, ExportedParameter, PatternMatchCounter, TypeFilterConstraint, BinaryTransitiveClosure
	 * 
	 * @param querySpecifications The list of IQuerySpecifications that we want to mutate.
	 * @param packageDeclaration Package declaration of the mutated patterns as string.
	 * @param imports Java imports as strings that are needed in the mutated patterns.
	 * @param outputFolder Output location of the mutated patterns as string. 
	 */
	def mutate(List<? extends IQuerySpecification<?>> querySpecifications, String packageDeclaration, Set<String> imports, String outputFolder) {		
		var specifications = new ArrayList<IQuerySpecification<?>>
		var pQueries = new HashSet<PQuery>
		var HashSet<PQuery> workingSetQueries = new HashSet<PQuery>
		var HashMap<String, String> mutatedQueries = new HashMap<String, String>
		var String outsourcedRepresentation = ""
		var String usedPackage = 
		'''
		package «packageDeclaration»
		
		'''
		var String allImports =		
		'''
		import "http://www.eclipse.org/emf/2002/Ecore"
		«FOR imp : imports.toList SEPARATOR "\\n" »import "«imp»"«ENDFOR»
		
		'''
		for (IQuerySpecification<?> specification : querySpecifications) {
			specifications.add(specification);
		}
		
		for (spec : specifications) {
			pQueries.add(spec.internalQueryRepresentation)
		}
	
		for (query : pQueries) {				
			var boolean go = true
			for (annotation : query.allAnnotations) {
				if(annotation.name == "QueryBasedFeature")
					go = false
			}			
			//Filter source queries
			if(go && query.disjunctBodies.bodies.forall[it.constraints.forall[it.class != BinaryTransitiveClosure]]){
				workingSetQueries.add(query)
			}							
		}

		for (workingQuery : workingSetQueries) {
			var int cntr = 1;	
			var PDisjunction normalizedPQuery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(workingQuery)
			var String representation = ""
			for (body : normalizedPQuery.bodies) {	
				for (constraint : body.constraints) {
					//TODO implement non-supported constraint types
					if (constraint.class != ConstantValue && constraint.class != AggregatorConstraint && constraint.class != ExpressionEvaluation && constraint.class != ExportedParameter && constraint.class != PatternMatchCounter && constraint.class != TypeFilterConstraint && constraint.class != BinaryTransitiveClosure ) {
						var p = new HelperPQuery(workingQuery, cntr, constraint)
						representation = getTextualRepresentationOfPQuery(p, false)
						mutatedQueries.put(p.name + cntr, representation)
						cntr++						
					}
				}
			}			
		}
		
		for (outsourcedQuery: outsourcedQueries.entrySet) {
				outsourcedRepresentation += (getTextualRepresentationOfPQuery(outsourcedQuery.value, false))
		}
		
		var FileWriter writer = null;
		var File file = null;
		var String vqlFile = ""
		
		file = new File(outputFolder + "outsourcedQueries.vql");
	    try {
	        writer = new FileWriter(file)	  
	        vqlFile += usedPackage
	        vqlFile += allImports
	        vqlFile += outsourcedRepresentation
	        writer.write(vqlFile)
	    } catch (IOException e) {
	        e.printStackTrace();
	    } finally {
	        if (writer !== null) try { writer.close(); } catch (IOException ignore) {}
	    }	    
		System.out.printf("File is located at %s%n", file.getAbsolutePath());
	
	
		for (key : mutatedQueries.keySet) {    		
			file = new File(outputFolder + key.split("\\.").last + ".vql");
			vqlFile = ""
		    try {
		        writer = new FileWriter(file);		  
		        vqlFile += usedPackage
		        vqlFile += allImports
		        vqlFile += mutatedQueries.get(key)		
		        writer.write(vqlFile);
		    } catch (IOException e) {
		        e.printStackTrace(); 
		    } finally {
		        if (writer !== null) try { writer.close(); } catch (IOException ignore) {}
		    }	    
  			System.out.printf("File is located at %s%n", file.getAbsolutePath());
		}				
	}
}

	