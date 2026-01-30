module.exports = ({ env }) => {
  const emailConfig = env('SMTP_HOST')
    ? {
        config: {
          provider: 'nodemailer',
          providerOptions: {
            host: env('SMTP_HOST'),
            port: env('SMTP_PORT', 587),
            auth: {
              user: env('SMTP_USERNAME'),
              pass: env('SMTP_PASSWORD'),
            },
          },
          settings: {
            defaultFrom: env('EMAIL_FROM'),
            defaultReplyTo: env('EMAIL_REPLY_TO'),
          },
        },
      }
    : {};

  return {
    'users-permissions': {
      config: {
        jwtSecret: env('JWT_SECRET'),
      },
    },
    upload: {
      config: {
        provider: '@strapi-community/strapi-provider-upload-google-cloud-storage',
        providerOptions: {
          bucketName: env('GCS_BUCKET_NAME'),
          baseUrl: env('GCS_BASE_URL'),
          publicFiles: env.bool('GCS_PUBLIC_FILES', true),
          uniform: env.bool('GCS_UNIFORM', true),
        },
      },
    },
    email: emailConfig,
  };
};
