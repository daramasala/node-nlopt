_ = require('lodash')
expect = require('expect.js')
nlopt = require("../nlopt.js")
request = require("request")

describe('basic', ()->
  checkResults = (actual, expected)->
    equal = _.isEqual(actual, expected, (a,b)->
      if _.isNumber(a) and _.isNumber(b)
        expect(a).to.be.within(b-.01,b+.01)
        return true
      if _.isString(a) and _.isString(b) and a.indexOf("Success")==0 and b.indexOf("Success")==0
        return true
      return undefined
    )
    if !equal then throw "#{if actual then JSON.stringify(actual) else 'undefined' } does not equal #{if expected then JSON.stringify(expected) else 'undefined'}"

  it('MLE Example', ()->
    data = [
      0.988877, 0.991881, 0.739757, 0.940761, 0.986811, 0.903514,
      0.984382, 0.888095, 0.864229, 0.95791, 0.915919, 0.990257, 0.94347,
      0.89609, 0.996033, 0.873548, 0.899078, 0.893999, 0.900032, 0.945644,
      0.843792, 0.932261, 0.810629, 0.971378, 0.994914, 0.954882, 0.96594,
      0.995431, 0.867875, 0.988802, 0.989609, 0.988265, 0.937092, 0.949935,
      0.880011, 0.872334, 0.880399, 0.96665, 0.774511, 0.848686, 0.863713,
      0.897073, 0.959902, 0.885167, 0.943062, 0.898766, 0.825464, 0.999472,
      0.924695, 0.874632
    ]
    erfc = (x)->
      z = Math.abs(x)
      t = 1 / (1 + z / 2)
      r = t * Math.exp(-z * z - 1.26551223 + t * (1.00002368 +
        t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 +
        t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 +
        t * (-0.82215223 + t * 0.17087277)))))))))
      return if x >= 0 then r else 2 - r
    sq = (x)->x*x
    log = Math.log
    objectiveFunc = (n, x)->
      partial = -0.9189385332046727 - log(x[1]) - log(0.5*erfc((0.7071067811865475*(-1 + x[0]))/x[1]) - 0.5*erfc((0.7071067811865475*x[0])/x[1]))
      return _.reduce(data, (sum, val)->
        return sum - (0.5*sq(val - x[0]))/sq(x[1]) + partial
      , 0)

    options = {
      algorithm: "LN_NELDERMEAD"
      numberOfParameters:2
      maxObjectiveFunction: objectiveFunc
      xToleranceRelative:1e-4
      initalGuess:[0.5, 0.5]
      lowerBounds:[0, -5]
      upperBounds:[1, 5]
    }
    expectedResult = { 
      maxObjectiveFunction: 'Success',
      lowerBounds: 'Success',
      upperBounds: 'Success',
      xToleranceRelative: 'Success',
      initalGuess: 'Success',
      status: 'Success: Optimization stopped because xToleranceRelative or xToleranceAbsolute was reached',
      parameterValues: [ 1, 0.1 ],
      outputValue: 78.4539 
    }
    checkResults(nlopt(options), expectedResult)
  )

  it('newton + simplex', ()->
    objectiveFunc = (n, x, grad)->
      if(grad)
        grad[0] = 16*x[0] - 4*x[0]*x[0]*x[0]
      x = 4 + 8*x[0]*x[0] - x[0]*x[0]*x[0]*x[0]

    #example from
    #http://www-rohan.sdsu.edu/~jmahaffy/courses/f00/math122/lectures/newtons_method/newtonmethodeg.html
    expectedResult = { 
      maxObjectiveFunction: 'Success'
      lowerBounds: 'Success'
      upperBounds: 'Success'
      xToleranceRelative: 'Success'
      inequalityConstraints: 'Failure: Invalid arguments'
      initalGuess: 'Success'
      status: 'Success'
      parameterValues: [ -2.00000000000279 ]
      outputValue: 20 
    }
    options = {
      algorithm: "NLOPT_LD_TNEWTON_PRECOND_RESTART"
      numberOfParameters:1
      maxObjectiveFunction: objectiveFunc
      inequalityConstraints:[{callback:(()->),tolerance:1}]#should not work for newton
      xToleranceRelative:1e-4
      initalGuess:[-1]
      lowerBounds:[-10]
      upperBounds:[10]
    }
    checkResults(nlopt(options), expectedResult)
    expectedResult.parameterValues[0] = 2
    options.initalGuess[0] = 2.5
    checkResults(nlopt(options), expectedResult)
    options.algorithm = "LN_NELDERMEAD"
    checkResults(nlopt(options), expectedResult)
  )
  it('example', ()->
    myfunc = (n, x, grad)->
      if(grad)
        grad[0] = 0.0
        grad[1] = 0.5 / Math.sqrt(x[1])
      return Math.sqrt(x[1])
    createMyConstraint = (cd)->
      return {
        callback:(n, x, grad)->
          if(grad)
            grad[0] = 3.0 * cd[0] * (cd[0]*x[0] + cd[1]) * (cd[0]*x[0] + cd[1])
            grad[1] = -1.0
          tmp = cd[0]*x[0] + cd[1]
          return tmp * tmp * tmp - x[1]
        tolerance:1e-8
      }
    expectedResult = { 
      minObjectiveFunction: 'Success'
      lowerBounds: 'Success'
      xToleranceRelative: 'Success'
      inequalityConstraints: 'Success'
      initalGuess: 'Success'
      status: 'Success: Optimization stopped because xToleranceRelative or xToleranceAbsolute was reached'
      parameterValues: [ 0.33333333465873644, 0.2962962893886998 ]
      outputValue: 0.5443310476067847 
    }
    options = {
      algorithm: "LD_MMA"
      numberOfParameters:2
      minObjectiveFunction: myfunc
      inequalityConstraints:[createMyConstraint([2.0, 0.0]), createMyConstraint([-1.0, 1.0])]
      xToleranceRelative:1e-4
      initalGuess:[1.234, 5.678]
      lowerBounds:[Number.MIN_VALUE, 0]
    }
    checkResults(nlopt(options), expectedResult)
    options.algorithm = "NLOPT_LN_COBYLA"
    checkResults(nlopt(options), expectedResult)

  )
)