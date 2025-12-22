import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.entities.users.Group
import org.cyclos.entities.users.User
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent
import org.cyclos.model.users.users.UserStatus

String comments = binding.comments
Map<String, Object> context = binding.context
User currentCopy = binding.currentCopy
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
Group newGroup = binding.newGroup
UserStatus newStatus = binding.newStatus
Group oldGroup = binding.oldGroup
UserStatus oldStatus = binding.oldStatus
User user = binding.user

throw new UnsupportedOperationException('Script not implemented')