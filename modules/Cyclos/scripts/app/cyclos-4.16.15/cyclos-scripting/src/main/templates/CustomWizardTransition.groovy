import org.cyclos.entities.system.CustomWizard
import org.cyclos.entities.system.CustomWizardExecution
import org.cyclos.entities.system.CustomWizardStep
import org.cyclos.entities.users.User
import org.cyclos.impl.system.CustomWizardExecutionStorage
import org.cyclos.impl.system.CustomWizardStepWithTransitions
import org.cyclos.model.users.users.PublicRegistrationDTO
import org.cyclos.model.utils.RequestInfo

Map<String, Object> customValues = binding.customValues
CustomWizardExecution execution = binding.execution
CustomWizardStep previousStep = binding.previousStep
PublicRegistrationDTO registration = binding.registration
RequestInfo request = binding.request
String returnUrl = binding.returnUrl
CustomWizardStep step = binding.step
CustomWizardStepWithTransitions steps = binding.steps
CustomWizardExecutionStorage storage = binding.storage
org.cyclos.impl.system.CustomWizardTransition transition = binding.transition
User user = binding.user
CustomWizard wizard = binding.wizard

throw new UnsupportedOperationException('Script not implemented')