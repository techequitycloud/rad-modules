import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.entities.users.Operator
import org.cyclos.entities.users.OperatorGroup
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent
import org.cyclos.model.users.users.UserStatus

String comments = binding.comments
Map<String, Object> context = binding.context
Operator currentCopy = binding.currentCopy
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
OperatorGroup newGroup = binding.newGroup
UserStatus newStatus = binding.newStatus
OperatorGroup oldGroup = binding.oldGroup
UserStatus oldStatus = binding.oldStatus
Operator operator = binding.operator

throw new UnsupportedOperationException('Script not implemented')