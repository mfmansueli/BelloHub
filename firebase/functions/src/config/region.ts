// One place for the region (docs/11-BACKEND-FIREBASE.md section 12, D29): Firestore eur3, Functions europe-west1,
// Storage EU, in every project. A test keeps this equal to firebase/config/<env>.json. A second database for Brazilian
// professionals (southamerica-east1) would be added here and in a slug-to-region lookup, nowhere else.

export type DataRegion = 'eu';

export const DATA_REGION: DataRegion = 'eu';
export const FUNCTIONS_REGION = 'europe-west1';
