import org.cyclos.entities.access.Channel
import org.cyclos.entities.access.SessionProperties
import org.cyclos.entities.users.BasicUser
import org.cyclos.entities.users.UserPrincipal
import org.cyclos.entities.utils.TimeInterval

Channel channel = binding.channel
UserPrincipal principal = binding.principal
String remoteAddress = binding.remoteAddress
SessionProperties sessionProperties = binding.sessionProperties
TimeInterval sessionTimeout = binding.sessionTimeout
Boolean trusted = binding.trusted
BasicUser user = binding.user

throw new UnsupportedOperationException('Script not implemented')