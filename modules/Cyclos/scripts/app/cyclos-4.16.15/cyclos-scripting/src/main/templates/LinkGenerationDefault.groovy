import org.cyclos.entities.access.IdentityProvider
import org.cyclos.entities.banking.PaymentTransferType
import org.cyclos.entities.banking.Ticket
import org.cyclos.entities.banking.TransactionCustomField
import org.cyclos.entities.banking.Voucher
import org.cyclos.entities.messaging.IncomingMessage
import org.cyclos.entities.users.BasicUser
import org.cyclos.entities.users.InviteToken
import org.cyclos.impl.system.CustomWizardExecutionStorage
import org.cyclos.impl.users.LocateUserResult
import org.cyclos.impl.utils.LinkType
import org.cyclos.model.messaging.notificationsettings.EmailUnsubscribeType
import org.cyclos.model.utils.Location

String entityId = binding.entityId
String entityIdParam = binding.entityIdParam
Object execution = binding.execution
IdentityProvider identityProvider = binding.identityProvider
InviteToken inviteToken = binding.inviteToken
Location location = binding.location
String mobileUrlFilePart = binding.mobileUrlFilePart
BigDecimal paymentAmount = binding.paymentAmount
Map<TransactionCustomField, String> paymentCustomValues = binding.paymentCustomValues
String paymentDescription = binding.paymentDescription
LocateUserResult paymentTo = binding.paymentTo
PaymentTransferType paymentType = binding.paymentType
IncomingMessage replyTo = binding.replyTo
String requestId = binding.requestId
CustomWizardExecutionStorage storage = binding.storage
Ticket ticket = binding.ticket
LinkType type = binding.type
String unsubscribeEmailKey = binding.unsubscribeEmailKey
EmailUnsubscribeType unsubscribeEmailType = binding.unsubscribeEmailType
String urlFilePart = binding.urlFilePart
BasicUser user = binding.user
String validationKey = binding.validationKey
Voucher voucher = binding.voucher

throw new UnsupportedOperationException('Script not implemented')